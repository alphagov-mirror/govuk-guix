(define-module (gds data data-extract)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-19)
  #:use-module (ice-9 match)
  #:use-module (guix gexp)
  #:use-module (guix monads)
  #:use-module (guix records)
  #:use-module (guix derivations)
  #:use-module (guix store)
  #:use-module (gnu services)
  #:use-module (gds utils)
  #:use-module (gds services utils databases postgresql)
  #:use-module (gds services utils databases mongodb)
  #:use-module (gds services utils databases mysql)
  #:use-module (gds services utils databases elasticsearch)
  #:use-module (gds data data-source)
  #:export (<data-extract>
            data-extract
            data-extract?
            data-extract-name
            data-extract-file
            data-extract-datetime
            data-extract-database
            data-extract-services
            data-extract-data-source
            data-extract-variant-name
            data-extract-variant-label
            data-extract-variant-properties
            data-extract-directory?

            filter-extracts
            group-extracts
            sort-extracts
            get-extracts-and-database-connection-configs
            database-connection-config-from-service-for-extract
            load-extract))

(define-record-type* <data-extract>
  data-extract make-data-extract
  data-extract?
  (name       data-extract-name)
  (file       data-extract-file)
  (datetime   data-extract-datetime)
  (database   data-extract-database)
  (services   data-extract-services)
  (data-source data-extract-data-source)
  (variant-name data-extract-variant-name
                (default '()))
  (variant-label data-extract-variant-label
                 (default '()))
  (variant-properties data-extract-variant-properties
                      (default '()))
  (directory? data-extract-directory?
              (default #f)))

(define* (filter-extracts extracts
                          #:optional #:key
                          service-types-and-extract-variant-names
                          databases
                          before-date
                          after-date)
  (filter
   (lambda (extract)
     (and
      (let ((services (data-extract-services extract)))
        (if (and services service-types-and-extract-variant-names)
            (any (match-lambda
                   ((service-type . variant-name)
                    (and (member service-type (data-extract-services extract))
                         (or (null? variant-name)
                             (and (not
                                   (null? (data-extract-variant-name extract)))
                                  (string=?
                                   variant-name
                                   (data-extract-variant-name extract)))))))
                 service-types-and-extract-variant-names)
            #t))
      (if databases
          (member (data-extract-database extract) databases)
          #t)
      (if before-date
          (time<? (date->time-utc (data-extract-datetime extract))
                   (date->time-utc before-date))
          #t)
      (if after-date
          (time>? (date->time-utc (data-extract-datetime extract))
                  (date->time-utc after-date))
          #t)))
   extracts))

(define (group-extracts field extracts)
  (fold (lambda (extract result)
          (let ((key (field extract)))
            (fold (lambda (key result)
                    (if (list? key) (error "key is a list"))
                    (alist-add key extract result))
                  result
                  (if (list? key)
                      key
                      (list key)))))
        '()
        extracts))

(define (sort-extracts extracts)
  "Sort EXTRACTS by time and priority so that the more recent and
higher priority extracts appear later in the list"
  (stable-sort
   extracts
   ;; Returns #t if b should rank higher than a, #f otherwise
   (lambda (a b)
     (let ((utc-time-a (date->time-utc (data-extract-datetime a)))
           (utc-time-b (date->time-utc (data-extract-datetime b))))
       (if (time=? utc-time-a utc-time-b)
           (let ((data-source-a (data-extract-data-source a))
                 (data-source-b (data-extract-data-source b)))
             (if (eq? data-source-a data-source-b)
                 ;; Does b have a higher priority than a?
                 (> (or (assoc-ref (data-extract-variant-properties b)
                                   'priority)
                        0)
                    (or (assoc-ref (data-extract-variant-properties a)
                                   'priority)
                        0))
                 ;; Does b have a higher priority than a?
                 (> (or (data-source-priority data-source-b) -1)
                    (or (data-source-priority data-source-a) -1))))
           ;; Is b more recent than a?
           (time>? utc-time-b utc-time-a))))))

(define (database-connection-config-from-service-for-extract service extract)
  (or
   (find
    (or
     (assoc-ref
      `(("postgresql"    . ,postgresql-connection-config?)
        ("mongo"         . ,mongodb-connection-config?)
        ("mysql"         . ,mysql-connection-config?)
        ("elasticsearch" . ,elasticsearch-connection-config?))
      (data-extract-database extract))
     (error "Unrecognised database type ~A" (data-extract-database extract)))
    (service-parameters service))
   (begin
     (display (service-parameters service))
     (error
      "Couldn't find a database connection configuration for ~A for the ~A service"
      (data-extract-database extract)
      (service-type-name (service-kind service))))))

(define (get-extracts-and-database-connection-configs services extracts)
  (fold
   (lambda (service data-extracts-and-database-connection-configs)
     (let ((service-extracts (filter-extracts
                              extracts
                              #:service-types-and-extract-variant-names
                              (list (cons
                                     (service-kind service)
                                     '())))))
       (fold
        (match-lambda*
          (((database . extracts) data-extracts-and-database-connection-configs)
           ;; The appropriate extract is always last in the list due
           ;; to sorting
           (let ((extract (last (sort-extracts extracts))))
             (alist-add
              extract
              (database-connection-config-from-service-for-extract service
                                                                   extract)
              data-extracts-and-database-connection-configs))))
        data-extracts-and-database-connection-configs
        (group-extracts data-extract-database service-extracts))))
   '()
   services))

(define* (load-extract extract database-connection-config
                       #:key dry-run?
                       (use-local-files-directly? #f))

  (define (transform-file file)
    (if (and use-local-files-directly?
             (local-file? file))
        (local-file-absolute-file-name file)
        file))

  (let* ((load-gexp
          (match extract
            (($ <data-extract> name file datetime "postgresql" services
                               data-source variant-name variant-label
                               variant-properties directory?)
             (if directory?
                 (postgresql-pg-restore-gexp
                  database-connection-config
                  (transform-file file)
                  #:dry-run? dry-run?)
                 (postgresql-import-gexp
                  database-connection-config
                  (transform-file file)
                  #:dry-run? dry-run?)))
            (($ <data-extract> name file datetime "mongo" services)
             (mongodb-restore-gexp
              database-connection-config
              (transform-file file)
              #:dry-run? dry-run?))
            (($ <data-extract> name file datetime "mysql" services)
             (mysql-run-file-gexp
              database-connection-config
              (transform-file file)
              #:dry-run? dry-run?))
            (($ <data-extract> name file datetime "elasticsearch" services)
             (elasticsearch-restore-gexp
              database-connection-config
              (simple-format
               #f "govuk-~A"
               (date->string datetime "~d-~m-~Y"))
              (transform-file file)
              #:alias "govuk"
              #:overrides "{\"settings\":{\"index\":{\"number_of_replicas\":\"0\",\"number_of_shards\":\"1\"}}}"
              #:batch-size 250
              #:dry-run? dry-run?))))
         (script
          (with-store store
            (run-with-store store
              (mlet* %store-monad
                  ((script (gexp->script
                            "load-extract"
                            #~(begin (exit (#$load-gexp))))))
                (mbegin %store-monad
                  (built-derivations (list script))
                  (return (derivation->output-path script))))))))
    (simple-format #t "running script ~A\n\n" script)
    (system* script)))
