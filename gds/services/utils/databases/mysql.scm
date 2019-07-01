(define-module (gds services utils databases mysql)
  #:use-module (ice-9 match)
  #:use-module (guix gexp)
  #:use-module (guix records)
  #:use-module (gnu packages databases)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages pv)
  #:export (<mysql-connection-config>
            mysql-connection-config
            mysql-connection-config?
            mysql-connection-config-host
            mysql-connection-config-user
            mysql-connection-config-port
            mysql-connection-config-database
            mysql-connection-config-password

            run-with-mysql-port
            mysql-list-databases-gexp
            mysql-ensure-user-exists-gexp
            mysql-create-database-gexp
            mysql-create-user-for-database-connection
            mysql-create-user-and-database-for-database-connection
            mysql-run-file-gexp))

(define-record-type* <mysql-connection-config>
  mysql-connection-config make-mysql-connection-config
  mysql-connection-config?
  (host mysql-connection-config-host
        (default "127.0.0.1"))
  (user mysql-connection-config-user)
  (port mysql-connection-config-port
        (default 3306))
  (database mysql-connection-config-database)
  (password mysql-connection-config-password))

(define (run-with-mysql-port database-connection operations)
  (match database-connection
    (($ <mysql-connection-config> host user port database)
     #~(lambda ()
         (use-modules (ice-9 popen))
         (let
             ((command `(,(string-append #$mariadb "/bin/mysql")
                         "-h" #$host
                         "-u" "root"
                         "--password="
                         "-P" ,(number->string #$port))))
           (simple-format #t "Connecting to mysql... (~A)\n" (string-join command))
           (let ((p (apply open-pipe* OPEN_WRITE command)))
             (for-each
              (lambda (o) (o p))
              (list #$@operations))
             (zero?
              (status:exit-val
               (close-pipe p)))))))))

(define* (mysql-run-file-gexp database-connection file
                              #:key dry-run?)
  (match database-connection
    (($ <mysql-connection-config> host user port database)
     #~(lambda ()
         (let*
             ((decompressor
               (cond
                ((string-suffix? "gz" #$file)
                 '(#$(file-append gzip "/bin/gzip")
                     "-d"
                     "|"))
                ((string-suffix? "bz2" #$file)
                 '(#$(file-append pbzip2 "/bin/pbzip2")
                     "-d"
                     "|"))
                ((string-suffix? "xz" #$file)
                 '(#$(file-append xz "/bin/xz")
                     "-d"
                     "|"))
                (else '())))
              (command `(,(string-append #$pv "/bin/pv")
                         ,#$file
                         "|"
                         ,@decompressor
                         ,(string-append #$mariadb "/bin/mysql")
                         "-h" #$host
                         "-u" "root"
                         "--protocol=tcp"
                         ,#$(string-append "--database=" database)
                         "--password=''"
                         "-P" ,(number->string #$port))))
           #$@(if dry-run?
                  '((simple-format #t "Would run command: ~A\n\n"
                                   (string-join command)))
                  '((simple-format #t "Running command: ~A\n\n"
                                   (string-join command))
                    (zero?
                     (system (string-join command))))))))))

(define (mysql-list-databases-gexp database-connection)
  (match database-connection
    (($ <mysql-connection-config> host user port database password)
     #~(lambda ()
         (use-modules (ice-9 popen)
                      (ice-9 rdelim))
         (let* ((command `(,(string-append #$mariadb "/bin/mysql")
                           "-h" #$host
                           "-u" #$user
                           "--protocol=tcp"
                           ,(string-append "--password=" #$password "")
                           "-P" ,(number->string #$port)
                           "--batch"  ;; tab separated output
                           "--skip-column-names"
                           "--execute=SHOW DATABASES;"))
                (p (apply open-pipe* OPEN_READ command))
                (lines (let loop ((lines '())
                                  (line (read-line p)))
                         (if (eof-object? line)
                             (reverse lines)
                             (loop (cons line lines)
                                   (read-line p))))))
           (and (let ((status (close-pipe p)))
                  (if (zero? status)
                      #t
                      (begin
                        (simple-format #t
                                       "command: ~A\n"
                                       (string-join command))
                        (error "listing databases failed, status ~A\n"
                               status))))
                (map (lambda (line)
                       (string-trim-both
                        (car (string-split line #\tab))))
                     lines)))))))

(define (mysql-ensure-user-exists-gexp user password)
  #~(lambda (port)
      (define (log-and-write p str . args)
        (display (apply simple-format #f str args))(display "\n")
        (apply simple-format p str args))

      (log-and-write port "
CREATE USER IF NOT EXISTS '~A'@'localhost' IDENTIFIED BY '~A';\n
" #$user #$password)))

(define (mysql-grant-all-privileges-for-database-gexp database user)
  #~(lambda (port)
      (define (log-and-write p str . args)
        (display (apply simple-format #f str args))(display "\n")
        (apply simple-format p str args))

      (log-and-write port "
GRANT ALL ON ~A.* TO '~A'@'localhost';\n
FLUSH PRIVILEGES;
" #$database #$user)))

(define (mysql-create-database-gexp database user)
  #~(lambda (port)
      (define (log-and-write p str . args)
        (display (apply simple-format #f str args))(display "\n")
        (apply simple-format p str args))

      (log-and-write port "
CREATE DATABASE IF NOT EXISTS ~A;\n" #$database)
      (log-and-write port "
GRANT ALL ON ~A.* TO '~A'@'localhost';\n" #$database #$user)))

(define (mysql-create-user-for-database-connection
         database-connection)
  (run-with-mysql-port
   database-connection
   (match database-connection
     (($ <mysql-connection-config> host user port database password)
      (list
       (mysql-ensure-user-exists-gexp user password)
       (mysql-grant-all-privileges-for-database-gexp database user))))))

(define (mysql-create-user-and-database-for-database-connection
         database-connection)
  (run-with-mysql-port
   database-connection
   (match database-connection
     (($ <mysql-connection-config> host user port database password)
      (list
       (mysql-ensure-user-exists-gexp user password)
       (mysql-create-database-gexp database user))))))
