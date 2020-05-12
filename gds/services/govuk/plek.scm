(define-module (gds services govuk plek)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-26)
  #:use-module (ice-9 match)
  #:use-module (web uri)
  #:use-module (guix records)
  #:use-module (guix gexp)
  #:use-module (gnu services)
  #:use-module (gnu services shepherd)
  #:use-module (gds services)
  #:use-module (gds services rails)
  #:export (<plek-config>
            plek-config
            plek-config?
            plek-config-govuk-app-domain
            plek-config-govuk-app-domain-external
            plek-config-govuk-asset-root
            plek-config-govuk-website-root
            plek-config-govuk-asset-host
            plek-config-draft-origin
            plek-config-dev-domain
            plek-config-service-ports
            plek-config-service-port-aliases
            plek-config-service-uri-function

            plek-config->environment-variables
            plek-config->/etc/hosts-string
            service-uri-from-plek-config
            service-port-from-plek-config
            service-host-from-plek-config
            make-custom-plek-config
            filter-plek-config-service-ports
            update-service-extension-parameters-for-plek-config
            modify-service-extensions-for-plek
            plek-config->domains))

(define-record-type* <plek-config>
  plek-config make-plek-config
  plek-config?
  (govuk-app-domain plek-config-govuk-app-domain
                    (default "publishing.service.gov.uk"))
  (govuk-app-domain-external plek-config-govuk-app-domain-external
                             (default "publishing.service.gov.uk"))
  (govuk-asset-root plek-config-govuk-asset-root
                    (default "https://assets.publishing.service.gov.uk"))
  (govuk-website-root plek-config-govuk-website-root
                      (default "https://www.gov.uk"))
  (govuk-asset-host plek-config-govuk-asset-host
                    (default "https://assets.publishing.service.gov.uk"))
  (draft-origin plek-config-draft-origin
                (default "https://draft-origin.publishing.service.gov.uk"))
  (dev-domain plek-config-dev-domain
              (default #f))
  (service-ports plek-config-service-ports
                 (default '()))
  (service-port-aliases plek-config-service-port-aliases
                        (default '()))
  (service-uri-function plek-config-service-uri-function
                        (default #f)))

(define (service-port-from-plek-config plek-config service)
  (or
   (or (assq-ref (plek-config-service-ports plek-config)
                 service)
       (and=> (find (match-lambda
                      ((service-with-aliases . aliases)
                       (if (memq service aliases)
                           service-with-aliases
                           #f)))
                    (plek-config-service-port-aliases plek-config))
              (lambda (service-with-aliases)
                (assq-ref (plek-config-service-ports plek-config)
                          (first service-with-aliases)))))
   (begin
     (display "plek-config-service-ports: ")
     (display (plek-config-service-ports plek-config))
     (display "\n")
     (backtrace)
     (error "Port missing from plek-config for" service))))

(define (service-uri-from-plek-config plek-config service)
  ((plek-config-service-uri-function plek-config)
   service
   (service-port-from-plek-config plek-config service)))

(define (service-host-from-plek-config plek-config service)
  (uri-host
   (string->uri
    (service-uri-from-plek-config plek-config service))))

(define (service-name->environment-variable-string service)
  (string-map
   (lambda (c)
     (if (eq? c #\-) #\_ c))
   (string-upcase service)))

(define* (make-custom-plek-config
          service-ports
          #:optional #:key
          (app-domain (plek-config-govuk-app-domain (plek-config)))
          (app-domain-external (plek-config-govuk-app-domain-external (plek-config)))
          (web-domain "www.gov.uk")
          (use-https? #t)
          (port (if use-https? 443 80))
          (aliases '()))
  (let
      ((scheme
        (if use-https? "https" "http"))
       (string-port
        (cond
         ((and use-https? (= port 443)) "")
         ((and (not use-https?) (= port 80)) "")
         (else (string-append
                ":" (number->string port))))))
    (plek-config
     (govuk-app-domain app-domain)
     (govuk-app-domain-external app-domain-external)
     (dev-domain
      (if use-https?
         ;; Plek uses DEV_DOMAIN to decide whether to use http or https
         app-domain
         #f))
     (govuk-asset-root
      (string-append scheme "://assets." app-domain string-port))
     (govuk-website-root
      (string-append scheme "://" web-domain string-port))
     (govuk-asset-host
      (string-append scheme "://assets." app-domain string-port))
     (draft-origin
      (string-append scheme "://draft-origin." app-domain string-port))
     (service-ports service-ports)
     (service-port-aliases aliases)
     (service-uri-function
      (lambda (service port)
        ;; For the default implementation, deliberately don't use
        ;; port, and just use string-port to route connections through
        ;; NGinx
        (string-append
         scheme
         "://"
         (symbol->string service)
         "."
         govuk-app-domain
         string-port))))))

(define (plek-config->/etc/hosts-string plek-config)
  (string-concatenate
   (map
    (cut string-append "127.0.0.1  " <> "\n")
    (plek-config->domains plek-config))))

(define* (plek-config->environment-variables
          plek-config
          #:optional #:key
          remove-draft-prefix?
          service-name-whitelist)
    (cons*
     (cons "GOVUK_APP_DOMAIN" (plek-config-govuk-app-domain plek-config))
     (cons "GOVUK_APP_DOMAIN_EXTERNAL" (plek-config-govuk-app-domain-external
                                        plek-config))
     (cons "GOVUK_ASSET_ROOT" (plek-config-govuk-asset-root plek-config))
     (cons "GOVUK_WEBSITE_ROOT" (plek-config-govuk-website-root plek-config))
     (cons "GOVUK_ASSET_HOST" (plek-config-govuk-asset-host plek-config))
     (cons "PLEK_SERVICE_DRAFT_ORIGIN_URI" (plek-config-draft-origin plek-config))
     (service-port-pairs->environment-variable-port-pairs
      plek-config
      (service-port-pairs plek-config service-name-whitelist)
      remove-draft-prefix?)))

(define (service-port-pairs->environment-variable-port-pairs
         plek-config
         service-port-pairs
         remove-draft-prefix?)
  (define (strip-draft-prefix-if-present s)
    (if (string-prefix? "draft-" s)
        (substring s (string-length "draft-"))
        s))

  (define name-and-port->service-uri
    (plek-config-service-uri-function plek-config))

  (map (match-lambda
         ((service . port)
          (cons
           (string-append
            "PLEK_SERVICE_"
            (service-name->environment-variable-string
             (let ((service-string (symbol->string service)))
               (if remove-draft-prefix?
                   (strip-draft-prefix-if-present service-string)
                   service-string)))
            "_URI")
           (name-and-port->service-uri service port))))
       service-port-pairs))

(define (service-port-pairs plek-config
                            service-name-whitelist)
  (concatenate
   (filter-map
    (match-lambda
      ((service . port)
       (and (if (list? service-name-whitelist)
                (memq service service-name-whitelist)
                #t)
            (map (lambda (name) (cons name port))
                 (cons
                  service
                  (or (assq-ref (plek-config-service-port-aliases plek-config)
                                service)
                      '()))))))
    (plek-config-service-ports plek-config))))

(define (update-service-extension-parameters-for-plek-config
         service-name
         parameters)
  (let
      ((plek-config (find plek-config? parameters))
       (shepherd-service (find
                          shepherd-service?
                          parameters)))
    (map
     (lambda (parameter)
       (cond
        ((service-startup-config? parameter)
         (service-startup-config-with-additional-environment-variables
          parameter
          (plek-config->environment-variables
           plek-config
           #:remove-draft-prefix?
           (string-prefix? "draft-" (symbol->string service-name))
           #:service-name-whitelist
           ;; The content stores are special, as while they don't
           ;; require the frontend services in the sense that they
           ;; must be running before the content-stores are started,
           ;; the information given to Plek is used when configuring
           ;; backends in the routers, and therefore needs to be
           ;; available.
           (cond
            ((eq? service-name 'content-store)
             ;; The live content store does not need to know about
             ;; draft services, so don't include them in the whitelist
             (remove (lambda (service)
                       (string-prefix? "draft-" (symbol->string service)))
                     (append
                      (map first (plek-config-service-ports plek-config))
                      (concatenate
                       (map cdr (plek-config-service-port-aliases plek-config))))))

            ((eq? service-name 'draft-content-store)
             ;; The draft content store shouldn't use the non-draft
             ;; versions of services
             (let ((service-names
                    (append
                     (map first (plek-config-service-ports plek-config))
                     (concatenate
                      (map cdr (plek-config-service-port-aliases plek-config))))))
               (filter (lambda (service)
                         (or
                          ;; Must be a draft service
                          (string-prefix? "draft-" (symbol->string service))
                          ;; or, no draft service exists
                          (not (memq (symbol-append 'draft- service)
                                     service-names))))
                       service-names)))

            (else
             (append
              ;; Some services (e.g. Whitehall) use Plek to find there
              ;; own host, so include it by default
              (list service-name)
              (concatenate
               (map
                (lambda (requirement)
                  (cons requirement
                        (or (assq-ref
                             (plek-config-service-port-aliases plek-config)
                             requirement)
                            '())))
                (shepherd-service-requirement shepherd-service)))))))))
        ((rails-app-config? parameter)
         (rails-app-config
          (inherit parameter)
          (port (service-port-from-plek-config
                 plek-config
                 service-name))))
        (else
         parameter)))
     parameters)))

(define (modify-service-extensions-for-plek name service-extensions)
  (map
   (lambda (se)
     (service-extension
      (service-extension-target se)
      (lambda (parameters)
        (apply
         (service-extension-compute se)
         (list
          (update-service-extension-parameters-for-plek-config
           name
           parameters))))))
   service-extensions))

(define-public (plek-config->hosts-file plek-config)
  (plain-file "hosts"
              (string-join
               (list
                "127.0.0.1 localhost"
                "::1 localhost"
                (plek-config->/etc/hosts-string plek-config))
               "\n")))

(define (plek-config->domains plek-config)
  (match-record
      plek-config
      <plek-config>
    (govuk-app-domain
     govuk-asset-root
     govuk-website-root
     govuk-asset-host
     draft-origin
     service-ports
     service-port-aliases)

    (append
     (list
      (uri-host (string->uri govuk-website-root))
      (uri-host (string->uri draft-origin)))
     (delete-duplicates
      (list
       (uri-host (string->uri govuk-asset-root))
       (uri-host (string->uri govuk-asset-host))))
     (append-map
      (match-lambda
        ((service . port)
         (map
          (lambda (name)
            (simple-format #f "~A.~A" name govuk-app-domain))
          (cons service
                (or (assq-ref service-port-aliases service)
                    '())))))
      service-ports))))
