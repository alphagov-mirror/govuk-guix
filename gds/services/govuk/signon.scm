(define-module (gds services govuk signon)
  #:use-module (srfi srfi-1)
  #:use-module (ice-9 match)
  #:use-module (ice-9 rdelim)
  #:use-module (srfi srfi-26)
  #:use-module (guix records)
  #:use-module (guix gexp)
  #:use-module (guix build utils)
  #:use-module (gnu services)
  #:use-module (gnu services shepherd)
  #:use-module (gds services)
  #:use-module (gds services utils)
  #:use-module (gds services utils databases)
  #:use-module (gds services utils databases mysql)
  #:use-module (gds services rails)
  #:use-module (gds services sidekiq)
  #:use-module (gds services govuk tailon)
  #:use-module (gds services govuk plek)
  #:export (<signon-application>
            signon-application
            signon-application?
            signon-application-name
            signon-application-description
            signon-application-redirect-uri
            signon-application-home-uri
            signon-application-supported-permissions
            signon-application-oauth-id
            signon-application-oauth-secret

            <signon-user>
            signon-user
            signon-user?
            signon-user-name
            signon-user-email
            signon-user-passphrase
            signon-user-application-permissions

            <signon-api-user>
            signon-api-user
            signon-api-user?
            signon-api-user-name
            signon-api-user-email
            signon-api-user-authorisation-permissions

            <signon-authorisation>
            signon-authorisation
            signon-authorisation?
            signon-authorisation-application-name
            signon-authorisation-token
            signon-authorisation-environment-variable

            use-gds-sso-strategy
            update-signon-application-with-random-oauth
            update-signon-api-user-with-random-authorisation-tokens
            filter-signon-user-application-permissions
            signon-setup-users-script
            signon-setup-api-users-script
            signon-setup-applications-script

            <signon-config>
            signon-config
            signon-config?
            signon-config-applications
            signon-config-users
            signon-config-devise-pepper
            signon-config-devise-secret-key
            signon-config-instance-name

            signon-config-with-random-secrets
            signon-dev-user-passphrase
            update-signon-service-add-users
            update-services-with-random-signon-secrets
            set-random-devise-secrets-for-the-signon-service

            modify-service-extensions-for-signon
            modify-service-extensions-for-signon-and-plek))

(define-record-type* <signon-application>
  signon-application make-signon-application
  signon-application?
  (name signon-application-name)
  (description signon-application-description
               (default ""))
  (redirect-uri signon-application-redirect-uri
                (default #f))
  (home-uri signon-application-home-uri
            (default #f))
  (supported-permissions signon-application-supported-permissions
                         (default '()))
  (oauth-id signon-application-oauth-id
            (default #f))
  (oauth-secret signon-application-oauth-secret
                (default #f)))

(define-record-type* <signon-user>
  signon-user make-signon-user
  signon-user?
  (name signon-user-name)
  (email signon-user-email)
  (passphrase signon-user-passphrase)
  (role signon-user-role)
  (application-permissions signon-user-application-permissions
                           (default '())))

(define-record-type* <signon-api-user>
  signon-api-user make-signon-api-user
  signon-api-user?
  (name signon-api-user-name)
  (email signon-api-user-email)
  (authorisation-permissions signon-api-user-authorisation-permissions
                             (default '())))

(define-record-type* <signon-authorisation>
  signon-authorisation make-signon-authorisation
  signon-authorisation?
  (application-name signon-authorisation-application-name)
  (token signon-authorisation-token
         (default #f))
  (environment-variable signon-authorisation-environment-variable
                        (default #f))) ;; If #f, the default pattern
                                       ;; will be used

(define (update-signon-application-with-random-oauth app)
  (signon-application
   (inherit app)
   (oauth-id (random-base16-string 64))
   (oauth-secret (random-base16-string 64))))

(define (update-signon-authorisation-with-random-token authorisation)
  (signon-authorisation
   (inherit authorisation)
   (token (random-base16-string 30))))

(define (update-signon-api-user-with-random-authorisation-tokens api-user)
  (signon-api-user
   (inherit api-user)
   (authorisation-permissions
    (map
     (match-lambda
       ((authorisation . permissions)
        (cons
         (update-signon-authorisation-with-random-token authorisation)
         permissions)))
     (signon-api-user-authorisation-permissions api-user)))))

(define (filter-signon-user-application-permissions user applications)
  (signon-user
   (inherit user)
   (application-permissions
    (let ((application-names
           (map
            (match-lambda (($ <signon-application> name) name)
                          ((and name string) name))
            applications)))
      (filter
       (lambda (permission)
         (member (car permission) application-names))
       (signon-user-application-permissions user))))))

(define (use-gds-sso-strategy services strategy)
  (map
   (lambda (s)
     (service
      (service-kind s)
      (if
       (list? (service-parameters s))
       (map
        (lambda (parameter)
          (if
           (service-startup-config? parameter)
           (service-startup-config-with-additional-environment-variables
            parameter
            `(("GDS_SSO_STRATEGY" . ,strategy)))
           parameter))
        (service-parameters s))
       (service-parameters s))))
   services))

(define (signon-setup-users-script signon-users)
  (plain-file
   "signon-setup-users.rb"
   (string-join
    `("users = ["
      ,(string-join
        (map
         (lambda (user)
           (define sq (cut string-append "'" <> "'"))

           (string-append
            "["
            (string-join
             (list
              (sq (signon-user-name user))
              (sq (signon-user-email user))
              (sq (signon-user-passphrase user))
              (sq (signon-user-role user))
              (string-append
               "["
               (string-join
                (map
                 (match-lambda
                   ((application . permissions)
                    (string-append
                     "[ '" application "', ["
                     (string-join (map sq permissions) ", ")
                     "]]")))
                 (signon-user-application-permissions user))
                ", ")
               "]"))
             ", ")
            "]"))
         signon-users)
       ",\n")
      "]"
      "
puts \"#{users.length} users to create\"

Devise.deny_old_passwords = false

users.each do |name, email, passphrase, role, application_permissions|
  puts \"Creating #{name}\"
  u = User.where(name: name, email: email).first_or_initialize
  u.password = passphrase
  u.role = role

  u.skip_invitation = true
  u.skip_confirmation!

  u.save!

  application_permissions.each do |application_name, permissions|
    app = Doorkeeper::Application.find_by_name!(application_name)
    u.grant_application_permissions(app, permissions)
  end
end")
    "\n")))

(define (signon-setup-api-users-script signon-api-users)
  (plain-file
   "signon-setup-api-users.rb"
   (string-join
    `("users = ["
      ,(string-join
        (map
         (lambda (user)
           (define sq (cut string-append "'" <> "'"))

           (string-append
            "  ["
            (string-join
             (list
              (sq (signon-api-user-name user))
              (sq (signon-api-user-email user))
              (string-append
               "["
               (string-join
                (map
                 (match-lambda
                   ((($ <signon-authorisation> application-name token)
                     .
                     permissions)
                    (string-append
                     "\n    ['" application-name "', '" token "', ["
                     (string-join (map sq permissions) ", ")
                     "]]")))
                 (signon-api-user-authorisation-permissions user))
                ",")
               "]"))
             ", ")
            "]"))
         signon-api-users)
       ",\n")
      "]"
      "
puts \"#{users.length} api users to create\"

users.each do |name, email, authorisation_permissions|
  puts \"Creating #{name}\"

  passphrase = SecureRandom.urlsafe_base64

  u = ApiUser.where(email: email).first_or_initialize(
    name: name,
    password: passphrase,
    password_confirmation: passphrase
  )
  u.api_user = true
  u.skip_confirmation!
  u.save!

  authorisation_permissions.each do |application_name, token, permissions|
    app = Doorkeeper::Application.find_by_name(application_name)

    unless app
      puts \"signon-setup-api-users: warning: #{application_name} not found, skipping\"
      next
    end

    u.grant_application_permissions(app, permissions)

    authorisation = u.authorisations.where(
      application_id: app.id
    ).first_or_initialize(
      application_id: app.id
    )

    authorisation.expires_in = ApiUser::DEFAULT_TOKEN_LIFE
    authorisation.save!

    authorisation.token = token
    authorisation.save!
  end
end")
    "\n")))

(define (signon-setup-applications-script signon-applications)
  (plain-file
   "signon-setup-applications.rb"
   (string-join
    `("apps = ["
      ,(string-join
        (map
         (lambda (app)
           (define sq (cut string-append "'" <> "'"))

           (string-append
            "["
            (string-join
             (list
              (sq (signon-application-name app))
              (sq (signon-application-description app))
              (sq (signon-application-redirect-uri app))
              (sq (signon-application-home-uri app))
              (string-append
               "["
               (string-join
                (map sq (signon-application-supported-permissions app))
                ", ")
              "]")
              (sq (signon-application-oauth-id app))
              (sq (signon-application-oauth-secret app)))
             ", ")
            "]"))
         signon-applications)
        ",\n")
      "]"
      "
puts \"#{apps.length} applications to create\"

apps.each do |name, description, redirect_uri, home_uri, supported_permissions, oauth_id, oauth_secret|
  puts \"Creating #{name}\"

  app = Doorkeeper::Application.where(name: name).first_or_create

  app.update!(
    redirect_uri: redirect_uri,
    description: description,
    home_uri: home_uri,
    uid: oauth_id,
    secret: oauth_secret
  )

  supported_permissions.each do |permission|
    SupportedPermission.where(
      name: permission,
      application_id: app.id
    ).first_or_create!
  end
end")
    "\n")))

(define-record-type* <signon-config>
  signon-config make-signon-config
  signon-config?
  (applications      signon-config-applications
                     (default '()))
  (users             signon-config-users
                     (default '()))
  (api-users         signon-config-api-users
                     (default '()))
  (devise-pepper     signon-config-devise-pepper
                     (default #f))
  (devise-secret-key signon-config-devise-secret-key
                     (default #f))
  (instance-name     signon-config-instance-name
                     (default #f)))

(define (signon-config-with-random-secrets config)
  (signon-config
   (inherit config)
   (devise-pepper     (random-base16-string 30))
   (devise-secret-key (random-base16-string 30))))

(define-public signon-service-type
  (service-type
   (name 'signon)
   (description "Single sign-on and user management service for GOV.UK")
   (extensions
    (service-extensions-modify-parameters
     (modify-service-extensions-for-plek
      name
      (standard-rails-service-type-extensions name))
     (lambda (parameters)
       (let ((config (find signon-config? parameters)))
         (map
          (lambda (parameter)
            (if (service-startup-config? parameter)
                (service-startup-config-add-pre-startup-scripts
                 (service-startup-config-with-additional-environment-variables
                  parameter
                  (let ((pepper (signon-config-devise-pepper config))
                        (secret-key (signon-config-devise-secret-key config))
                        (instance-name (signon-config-instance-name config)))
                    `(,@(if pepper
                            `(("DEVISE_PEPPER" . ,pepper))
                            '())
                      ,@(if secret-key
                            `(("DEVISE_SECRET_KEY" . ,secret-key))
                            '())
                      ,@(if instance-name
                            `(("INSTANCE_NAME" . ,instance-name))
                            '()))))
                 `((signon-setup
                    .
                    ,#~(lambda ()
                         (run-command
                          "rails" "runner"
                          (string-join
                           (map
                            (lambda (script)
                              (string-append "load '" script "';"))
                            (list
                             #$(signon-setup-applications-script
                                (signon-config-applications config))
                             #$(signon-setup-users-script
                                (map
                                 (cut filter-signon-user-application-permissions
                                   <> (signon-config-applications config))
                                 (signon-config-users config)))
                             #$(signon-setup-api-users-script
                                (signon-config-api-users config))))))))))
                parameter))
          parameters)))))
   (compose concatenate)
   (extend (lambda (parameters extension-parameters)
             (map
              (lambda (parameter)
                (if (signon-config? parameter)
                    (signon-config
                     (inherit parameter)
                     (applications (append
                                    (signon-config-applications parameter)
                                    (filter signon-application?
                                            extension-parameters)))
                     (users (append
                             (signon-config-users parameter)
                             (filter signon-user?
                                     extension-parameters)))
                     (api-users (append
                                 (signon-config-api-users parameter)
                                 (filter signon-api-user?
                                         extension-parameters))))
                    parameter))
              parameters)))
   (default-value
     (list (shepherd-service
            (inherit default-shepherd-service)
            (provision '(signon))
            (requirement '(mysql loopback redis)))
           (service-startup-config)
           (plek-config) (rails-app-config) (@ (gds packages govuk) signon)
           (signon-config)
           (sidekiq-config
            (file "config/sidekiq.yml"))
           (mysql-connection-config
            (user "signon")
            (database "signon_production")
            (password (random-base16-string 30)))
           (redis-connection-config)))))

(define (signon-dev-user-passphrase)
  (define (new-passphrase)
    (random-base16-string 16))

  (or (getenv "GOVUK_GUIX_DEVELOPMENT_PASSPHRASE")
      (let ((data-dir (or (getenv "XDG_DATA_HOME")
                            (and=> (getenv "HOME")
                                   (cut string-append <> "/.local/share")))))
        (if (file-exists? data-dir)
            (let* ((govuk-guix-dir
                    (string-append data-dir "/govuk-guix"))
                   (system-dir
                    (string-append govuk-guix-dir "/systems/development"))
                   (passphrase-file
                    (string-append system-dir "/passphrase")))
              (if (file-exists? passphrase-file)
                  (call-with-input-file passphrase-file read-line)
                  (let ((passphrase (new-passphrase)))
                    (mkdir-p system-dir)
                    (call-with-output-file passphrase-file
                      (cut display passphrase <>))
                    passphrase)))
            (let ((passphrase (new-passphrase)))
              (simple-format #t "\nUnable to find directory to place
the Signon Dev user passphrase in\n")
              (simple-format #t "The following passphrase will be used, but this will not be persisted: ~A\n\n" passphrase)
              passphrase)))))

(define (update-signon-service-add-users users services)
  (update-services-parameters
   services
   (list
    (cons
     signon-service-type
     (list
      (cons
       signon-config?
       (lambda (config)
         (signon-config
          (inherit config)
          (users
           (append (signon-config-users config)
                   users))))))))))

(define (update-services-with-random-signon-secrets services)
  (map
   (lambda (service)
     (update-service-parameters
      service
      (list
       (cons
        signon-application?
        (lambda (app)
          (update-signon-application-with-random-oauth app)))
       (cons
        signon-api-user?
        (lambda (api-user)
          (update-signon-api-user-with-random-authorisation-tokens api-user))))))
   services))

(define (set-random-devise-secrets-for-the-signon-service services)
  (modify-services
      services
    (signon-service-type
     parameters =>
     (map
      (lambda (parameter)
        (if (signon-config? parameter)
            (signon-config-with-random-secrets parameter)
            parameter))
      parameters))))

(define (update-service-startup-config-for-signon-application parameters)
  (let ((signon-application (find signon-application? parameters)))
    (if signon-application
        (map
         (lambda (parameter)
           (if (service-startup-config? parameter)
               (service-startup-config-with-additional-environment-variables
                parameter
                `(("OAUTH_ID" . ,(signon-application-oauth-id
                                  signon-application))
                  ("OAUTH_SECRET" . ,(signon-application-oauth-secret
                                      signon-application))))
               parameter))
         parameters)
        parameters)))

(define (update-service-startup-config-for-signon-api-user parameters)
  (map
   (lambda (parameter)
     (if (service-startup-config? parameter)
         (service-startup-config-with-additional-environment-variables
          parameter
          (map
           (match-lambda
             (($ <signon-authorisation> application-name token
                                        environment-variable)
              (let ((name
                     (or environment-variable
                         (string-append
                          (string-map
                           (lambda (c)
                             (if (eq? c #\space) #\_ c))
                           (string-upcase application-name))
                          "_BEARER_TOKEN"))))
                (cons name token))))
           (concatenate
            (map
             (match-lambda
               (($ <signon-api-user> name email authorisation-permissions)
                (map car authorisation-permissions)))
             (filter signon-api-user? parameters)))))
         parameter))
   parameters))

(define (update-signon-application name parameters)
  (let ((plek-config (find plek-config? parameters)))
    (if plek-config
        (map
         (lambda (parameter)
           (if (signon-application? parameter)
               (let ((service-uri
                      (if (eq? name 'authenticating-proxy)
                          (plek-config-draft-origin plek-config)
                          (service-uri-from-plek-config plek-config
                                                        name))))
                 (signon-application
                  (inherit parameter)
                  (home-uri service-uri)
                  (redirect-uri
                   (string-append service-uri "/auth/gds/callback"))))
               parameter))
         parameters)
        parameters)))

(define (generic-rails-app-log-files name . rest)
  (let*
      ((string-name (symbol->string name))
       (ss (find shepherd-service? rest))
       (sidekiq-config (find sidekiq-config? rest))
       (sidekiq-service-name
        (string-append
         (symbol->string
          (first (shepherd-service-provision ss)))
         "-sidekiq")))
    (cons
     (string-append "/var/log/" string-name ".log")
     (if sidekiq-config
         (list
          (string-append "/var/log/" sidekiq-service-name ".log"))
         '()))))

(define (assert-shepherd-service-requirements-contain-signon parameters)
  (and=> (find signon-application? parameters)
         (lambda (signon-application)
           (and=> (find shepherd-service? parameters)
                  (lambda (shepherd-service)
                    (unless (memq 'signon
                                  (shepherd-service-requirement shepherd-service))
                      (error (string-append
                              "Missing signon requirement for "
                              (signon-application-name signon-application)))))))))

(define (modify-service-extensions-for-signon name service-extensions)
  (service-extensions-modify-parameters
   (cons*
    (service-extension signon-service-type
                       (lambda (parameters)
                         (assert-shepherd-service-requirements-contain-signon parameters)

                         (filter
                          (lambda (parameter)
                            (or (signon-application? parameter)
                                (signon-api-user? parameter)
                                (signon-user? parameter)))
                          parameters)))
    ;; TODO Ideally this would not be in this module, as it's not
    ;; directly related to Signon
    ;; (service-extension govuk-tailon-service-type
    ;;                    (lambda (parameters)
    ;;                      (let ((log-files
    ;;                             (apply
    ;;                              generic-rails-app-log-files
    ;;                              name
    ;;                              parameters)))
    ;;                        (if (eq? (length log-files) 1)
    ;;                            log-files
    ;;                            (list
    ;;                             (cons (symbol->string name)
    ;;                                   log-files))))))
    service-extensions)
   (lambda (parameters)
     (update-service-startup-config-for-signon-application
      (update-service-startup-config-for-signon-api-user
       (update-signon-application name parameters))))))

(define (modify-service-extensions-for-signon-and-plek name service-extensions)
  (modify-service-extensions-for-signon
   name
   (modify-service-extensions-for-plek name service-extensions)))
