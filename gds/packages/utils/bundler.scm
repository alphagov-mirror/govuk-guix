(define-module (gds packages utils bundler)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-26)
  #:use-module (ice-9 ftw)
  #:use-module (ice-9 match)
  #:use-module (guix monads)
  #:use-module (guix records)
  #:use-module (guix gexp)
  #:use-module (guix grafts)
  #:use-module (guix packages)
  #:use-module (guix profiles)
  #:use-module (guix self)
  #:use-module (guix modules)
  #:use-module (guix store)
  #:use-module (guix ui)
  #:use-module (guix utils)
  #:use-module (guix base32)
  #:use-module (guix download)
  #:use-module (guix derivations)
  #:use-module (guix search-paths)
  #:use-module (guix build-system ruby)
  #:use-module (guix build-system gnu)
  #:use-module (guix build utils)
  #:use-module (gnu packages base)
  #:use-module ((gnu packages ruby) #:prefix guix:)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages version-control)
  #:use-module (gnu packages guile)
  #:use-module (gnu packages gnupg)
  #:use-module (gnu packages certs)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages xml)
  #:use-module (gds build-system rails)
  #:use-module (gds packages utils)
  #:use-module (gds packages utils bundler-build)
  #:export (<bundle-package>
            bundle-package
            bundle-package?
            bundle-package-source
            bundle-package-name
            bundle-package-hash
            bundle-package-ruby
            bundle-package-without
            bundle-package-location

            ruby-for-package
            bundle-package-to-store
            package-with-bundler
            extract-bundle-package-from-package
            update-bundle-package-source))

(define (patch-ruby ruby)
  (package
    (inherit ruby)
    (arguments
     (substitute-keyword-arguments
         (default-keyword-arguments
           (package-arguments guix:ruby)
           `(#:tests? #t))
       ((#:tests? _) #t)
       ((#:phases phases)
        `(modify-phases ,phases
           (add-after
            'configure 'patch-for-reproducible-gemspecs
            (lambda _
              (substitute* "lib/rubygems/specification.rb"
                (("current_value = self\\.send\\(attr_name\\)")
                 "current_value = self.send(attr_name)\n      current_value = current_value.sort if %i(files test_files).include? attr_name  # patched through govuk-guix"))))))))))

(define (ruby-for-package pkg)
  (define* (ruby-from-package-arguments #:key (ruby (default-ruby))
                                        #:allow-other-keys)
    ruby)

  (apply ruby-from-package-arguments
         (package-arguments pkg)))

(define (bundler ruby)
  (package
    (inherit guix:bundler)
    (arguments
     (ensure-keyword-arguments
      (package-arguments guix:bundler)
      `(#:ruby ,(patch-ruby ruby))))))

(define-record-type* <bundle-package>
  bundle-package make-bundle-package
  bundle-package?
  (source bundle-package-source
          (default #f))
  (name bundle-package-name
        (default "bundle-package"))
  (hash bundle-package-hash)
  (ruby bundle-package-ruby
        (default default-ruby))
  (without bundle-package-without
           (default '()))
  (location bundle-package-location
            (default (and=> (current-source-location)
                            source-properties->location))
            (innate)))

(define (bundle-package-inputs ruby)
  (list coreutils
        sed
        ruby
        tar
        gzip
        (bundler ruby)
        git))

(define-gexp-compiler (bundle-package-for-source-compiler
                       (bundle-package <bundle-package>) system target)
  ;; "Compile" FILE by adding it to the store.
  (match bundle-package
    (($ <bundle-package> source name hash ruby without)
     (mlet %store-monad ((ca-certificates
                          (ca-certificate-bundle
                           (packages->manifest (list nss-certs)))))
       (define inputs
         (bundle-package-inputs ruby))

       (define search-paths
         (map
          search-path-specification->sexp
          (delete-duplicates
           (append-map
            package-native-search-paths
            inputs))))

       (define ruby-version (package-version ruby))

       (define libgcrypt
         (module-ref (resolve-interface '(gnu packages gnupg))
                     'libgcrypt))

       (define not-config?
         ;; Select (guix …) and (gnu …) modules, except (guix config).
         (match-lambda
           (('guix 'config) #f)
           (('guix _ ...) #t)
           (('gnu _ ...) #t)
           (_ #f)))

       (define gcrypt-sqlite3&co
         ;; Guile-Gcrypt, Guile-SQLite3, and their propagated inputs.
         (append-map (lambda (package)
                       (cons package
                             (package-transitive-propagated-inputs package)))
                     (list guile-gcrypt guile-sqlite3)))

       (define build
         (with-extensions gcrypt-sqlite3&co
           (with-imported-modules `((gds packages utils bundler-build)
                                    ((guix config)
                                     => ,(make-config.scm))
                                    ,@(source-module-closure
                                       '((guix build utils)
                                         ;; for reset-timestamps
                                         (guix store database)
                                         (guix build store-copy))
                                       #:select? not-config?))
             #~(begin
                 (use-modules (gds packages utils bundler-build))
                 (run-bundle-package #$source
                                     #$output
                                     (getcwd)
                                     '#$inputs
                                     #$ca-certificates
                                     #$nss-certs
                                     '#$search-paths
                                     '#$without
                                     #$ruby-version)))))

       (gexp->derivation name build
                         #:system system
                         #:local-build? #t
                         #:hash-algo 'sha256
                         #:hash hash
                         #:recursive? #t
                         #:local-build? #t)))))

(define bundle-package-to-store
  (match-lambda
    (($ <bundle-package> source name hash ruby without)
     (parameterize ((%graft? #f))
       (with-store store
        (let* ((inputs (bundle-package-inputs ruby))
               (input-derivations (map (cut package-derivation store <>)
                                       inputs))
               (input-store-outputs (map derivation->output-path
                                         input-derivations))
               (source-derivation (and (not (string? source))
                                       ((store-lower lower-object)
                                        store source)))
               (source-store-path (if (string? source)
                                      source
                                      (if (string? source-derivation)
                                          source-derivation
                                          (derivation->output-path source-derivation))))
               (nss-certs-derivation (package-derivation store nss-certs))
               (nss-certs-store-output (derivation->output-path
                                        nss-certs-derivation))
               (ca-certificates-derivation
                ((ca-certificate-bundle
                  (packages->manifest (list nss-certs)))
                 store))
               (ca-certificates-store-output (derivation->output-path
                                              ca-certificates-derivation))
               (search-paths
                (map
                 search-path-specification->sexp
                 (delete-duplicates
                  (append-map package-native-search-paths
                              inputs))))
               (working-directory (tmpnam))
               (output (string-append working-directory "/output")))

          (build-derivations store `(,@(if (derivation? source-derivation)
                                           (list source-derivation)
                                           '())
                                     ,nss-certs-derivation
                                     ,ca-certificates-derivation
                                     ,@input-derivations))

          (with-throw-handler #t
            (lambda ()
              (run-bundle-package source-store-path
                                  output
                                  working-directory
                                  input-store-outputs
                                  ca-certificates-store-output
                                  nss-certs-store-output
                                  search-paths
                                  without
                                  (package-version ruby)))
            (lambda (key args)
              (display "exception thrown: deleting the working directory\n"
                       (current-error-port))
              (ftw working-directory
                   (lambda (filename statinfo flag)
                     (if (eq? flag 'directory)
                         (chmod filename #o755))
                     #t))
              (delete-file-recursively working-directory)))

          (let ((path
                 (add-to-store store name #t "sha256" output)))
            (simple-format #t "bundle-package-to-store: output path: ~A\n"
                           path)
            (ftw working-directory
                 (lambda (filename statinfo flag)
                   (if (eq? flag 'directory)
                       (chmod filename #o755))
                   #t))
            (delete-file-recursively working-directory)
            path)))))))

(define (gemrc ruby)
  (mixed-text-file "gemrc"
                   "custom_shebang: " ruby "/bin/ruby\n"))

(define* (bundle-install-package
          bundle-pkg
          pkg
          #:key
          (extra-inputs '()))
  (package
    (name (string-append (package-name pkg) "-bundle-install"))
    (version (string-take
              (bytevector->nix-base32-string
               (bundle-package-hash bundle-pkg))
              10))
    (source (bundle-package
             (inherit bundle-pkg)
             (location (bundle-package-location bundle-pkg))
             (source (or (bundle-package-source bundle-pkg)
                         (package-source pkg)))
             (name (string-append (package-name pkg) "-bundle-package"))))
    (build-system gnu-build-system)
    (arguments
     `(#:modules ((srfi srfi-1)
                  (ice-9 ftw)
                  ,@%gnu-build-system-modules)
       #:phases
       (modify-phases %standard-phases
         (delete 'validate-runpath)
         (delete 'configure)
         (delete 'check)
         (delete 'install)
         (add-after 'patch-generated-file-shebangs 'set-bundle-without
           (lambda _
             (setenv "BUNDLE_WITHOUT"
                     ,(string-join
                       (bundle-package-without bundle-pkg)
                       ":"))
             #t))
         (add-after 'set-bundle-without 'path-remove-source
           (lambda _
             (setenv
              "PATH"
              (list->search-path-as-string
               (filter
                (lambda (path)
                  (not (string-prefix?
                        (assoc-ref %build-inputs "source")
                        path)))
                (search-path-as-string->list (getenv "PATH")))
               ":"))
             #t))
         (add-after 'path-remove-source 'set-ld-library-path
           (lambda* (#:key inputs #:allow-other-keys)
             (set-path-environment-variable
              "LD_LIBRARY_PATH"
              '("lib")
              (map cdr inputs))
             #t))
         (add-after 'set-ld-library-path 'remove-ruby-version
           ,(remove-ruby-version (package-version
                                  (bundle-package-ruby bundle-pkg))))
         (replace 'build
           (lambda* (#:key inputs outputs #:allow-other-keys)
             (let* ((cwd (getcwd))
                    (out (assoc-ref outputs "out")))
               (setenv "GEMRC"  (assoc-ref %build-inputs "gemrc"))
               (setenv "CC" "gcc")
               (if (file-exists? (string-append cwd "/.bundle/config"))
                   (chmod (string-append cwd "/.bundle/config") #o644))
               (invoke "bundle"
                       "config"
                       "--local"
                       "build.nokogiri"
                       "--use-system-libraries")
               (invoke "bundle"
                       "install"
                       "--local"
                       "--deployment"
                       (string-append "--jobs="
                                      (number->string (parallel-job-count))))

               (mkdir-p (string-append (assoc-ref outputs "out")
                                       "/vendor/bundle/"))
               (let* ((prefix "vendor/bundle/ruby")
                      (ruby-version
                       (first
                        (scandir prefix
                                 (negate
                                  (lambda (f)
                                    (member f '("." ".."))))))))
                 (for-each
                  (lambda (file)
                    (copy-recursively
                     (string-append prefix "/" ruby-version "/" file)
                     (string-append (assoc-ref outputs "out")
                                    "/vendor/bundle/"
                                    (basename file))
                     #:log (%make-void-port "w")))
                  (scandir (string-append prefix "/" ruby-version)
                           (negate
                            (lambda (f)
                              (member f '("." ".."))))))))
             #t))
         (add-after 'build 'install-bundle-package-cache
           (lambda* (#:key inputs outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out")))
               (mkdir (string-append out "/vendor/bundle/bundler"))
               (symlink
                (string-append
                 (assoc-ref inputs "source")
                 "/vendor/cache")
                (string-append out "/vendor/bundle/bundler/gems")))
             #t))
         (add-after 'build 'patch-gem-bin-files
           (lambda* (#:key outputs #:allow-other-keys)
             (let ((gems
                    (string-append
                     (assoc-ref outputs "out")
                     "/vendor/bundle/gems")))
               (for-each
                (lambda (gem)
                  (let ((bin (string-append gems "/" gem "/bin")))
                    (if (directory-exists? bin)
                        (for-each patch-shebang (find-files bin)))))
                (scandir gems
                         (negate
                          (lambda (f)
                            (member f '("." "..")))))))
             #t))
         (add-after 'build 'patch-tzinfo-data-source
           (lambda* (#:key inputs outputs #:allow-other-keys)
             (substitute* (find-files
                           (string-append
                            (assoc-ref outputs "out")
                            "/vendor/bundle/gems")
                           "zoneinfo_data_source.rb")
               (("DEFAULT_SEARCH_PATH = .*$")
                (string-append
                 "DEFAULT_SEARCH_PATH = ['"
                 (assoc-ref inputs "tzdata") "/share/zoneinfo"
                 "'].freeze")))
             #t)))))
    (inputs
     (let ((ruby (bundle-package-ruby bundle-pkg)))
       (cons*
        (list "ruby" ruby)
        (list "bundler" (bundler ruby))
        (list "gemrc" (gemrc ruby))
        (list "tzdata" tzdata)
        (map (lambda (package)
               (list (package-name package) package))
             extra-inputs))))
    (synopsis "")
    (license "")
    (description "")
    (home-page "")))

(define* (package-with-bundler
          bundle-pkg
          pkg
          #:key
          (extra-inputs '()))
  (let
      ((ruby (ruby-for-package pkg)))
    (package
      (inherit pkg)
      ;; Pass through the original location
      (location (package-location pkg))
      (arguments
       (substitute-keyword-arguments
           (default-keyword-arguments
             (package-arguments pkg)
             `(#:modules
               ,(or
                 (assq-ref
                  `((,gnu-build-system . ,%gnu-build-system-modules)
                    (,rails-build-system . ,%rails-build-system-modules))
                  (package-build-system pkg))
                 (error "package-with-bundler, unsupported build system:"
                        (package-build-system pkg)))
               #:phases %standard-phases))
         ((#:modules modules)
          `((srfi srfi-1)
            (ice-9 ftw)
            ,@modules))
         ((#:phases phases)
          `(modify-phases ,phases
             (delete 'set-bundle-without)
             (delete 'path-remove-source)
             (delete 'bundle-install)
             (delete 'patch-tzinfo-data-source)
             (delete 'wrap-bin-files-for-bundler)
             (add-before 'configure 'set-bundle-without
               (lambda _
                 (setenv "BUNDLE_WITHOUT"
                         ,(string-join
                           (bundle-package-without bundle-pkg)
                           ":"))
                 #t))
             (add-after 'set-bundle-without 'path-remove-source
               (lambda _
                 (setenv
                  "PATH"
                  (list->search-path-as-string
                   (filter
                    (lambda (path)
                      (not (string-prefix?
                            (assoc-ref %build-inputs "source")
                            path)))
                    (search-path-as-string->list (getenv "PATH")))
                   ":"))
                 #t))
             (add-after 'path-remove-source 'ensure-/bin/bundle-exists
               (lambda* (#:key inputs outputs #:allow-other-keys)
                 (let*
                     ((out (assoc-ref outputs "out"))
                      (gemfile (string-append out "/Gemfile"))
                      (ruby
                       (string-append (assoc-ref inputs "ruby")
                                      "/bin/ruby"))
                      (bundle
                       (string-append (getcwd) "/bin/bundle")))
                   (if (not (file-exists? bundle))
                       (begin
                         (mkdir-p (string-append (getcwd) "/bin"))
                         (call-with-output-file bundle
                           (lambda (port)
                             (format port "#!~A
ENV[\"BUNDLE_GEMFILE\"] ||= \"~A\"

load Gem.bin_path(\"bundler\", \"bundler\")" ruby gemfile)))
                         (chmod bundle #o544)))
                   #t)))
             (add-after 'ensure-/bin/bundle-exists 'set-ld-library-path
               (lambda* (#:key inputs #:allow-other-keys)
                 (set-path-environment-variable
                  "LD_LIBRARY_PATH"
                  '("lib")
                  (filter-map
                   (lambda (input)
                     (if (member (car input)
                                 ',(map car (package-inputs pkg)))
                         (cdr input)
                         #f))
                   inputs))
                 #t))
             (add-after 'set-ld-library-path 'remove-ruby-version
               ,(remove-ruby-version (package-version ruby)))
             (add-before 'configure 'add-bundle-install-bin-to-path
               (lambda* (#:key inputs #:allow-other-keys)
                 (use-modules (srfi srfi-1)
                              (ice-9 ftw))
                 (let ((bin
                        (string-append
                         (assoc-ref %build-inputs "bundle-install")
                         "/vendor/bundle/bin")))
                   (setenv
                    "PATH"
                    (list->search-path-as-string
                     (cons*
                      bin
                      (search-path-as-string->list (getenv "PATH")))
                     ":")))
                 #t))
             (add-after 'add-bundle-install-bin-to-path
                        'add-bundle-install-gems-to-path
               (lambda* (#:key inputs #:allow-other-keys)
                 (setenv "BUNDLE_PATH"
                         (string-append
                          (assoc-ref %build-inputs "bundle-install")
                          "/vendor/bundle"))
                 (setenv
                  "GEM_PATH"
                  (list->search-path-as-string
                   (cons*
                    (string-append (assoc-ref %build-inputs "bundle-install")
                                   "/vendor/bundle/gems")
                    (search-path-as-string->list (getenv "GEM_PATH")))
                   ":"))
                 #t))
           (add-after 'install 'wrap-bin-files-for-bundler
             (lambda* (#:key inputs outputs #:allow-other-keys)
               (let* ((out (assoc-ref outputs "out"))
                      (gem_home
                       (string-append
                        (assoc-ref %build-inputs "bundle-install")
                        "/vendor/bundle/gems")))
               (for-each
                  (lambda (script)
                    (chmod script #o777)
                    (wrap-program
                        script
                      `("PATH" ":" prefix
                        ,(let ((bin
                                (string-append
                                 (assoc-ref %build-inputs "bundle-install")
                                 "/vendor/bundle/bin")))
                           (cons*
                            bin
                            (search-path-as-list
                             '("bin" "sbin")
                             (filter-map
                              (lambda (input)
                                (if (member (car input)
                                            ',(map car (package-inputs pkg)))
                                    (cdr input)
                                    #f))
                              inputs)))))
                      `("GEM_PATH" ":" prefix (,(getenv "GEM_PATH")))
                      `("BUNDLE_PATH" = (,(getenv "BUNDLE_PATH")))
                      `("BUNDLE_WITHOUT" ":" prefix (,(getenv "BUNDLE_WITHOUT")))
                      '("BUNDLE_APP_CONFIG" = ("/dev/null"))
                      `("LD_LIBRARY_PATH" ":" prefix
                        ,(or (and=> (getenv "LD_LIBRARY_PATH") list)
                             '()))))
                  (find-files
                   (string-append out "/bin")
                   (lambda (name stat)
                     (and
                      (not (string-prefix? "." (last (string-split name #\/))))
                      (or
                       (access? name X_OK)
                       (begin
                         (simple-format #t "Skipping wrapping ~A as its not executable\n" name)
                         #f))))))
               #t)))))))
    (inputs
     (cons*
      (list "bundler" (bundler ruby))
      (list "bundle-install" (bundle-install-package
                              (bundle-package
                               (inherit bundle-pkg)
                               (location (bundle-package-location bundle-pkg))
                               (ruby ruby))
                              pkg
                              #:extra-inputs (append
                                              extra-inputs
                                              (cond
                                               ((eq? (package-build-system pkg)
                                                     rails-build-system)
                                                (list
                                                 ;; Dependencies of nokogiri
                                                 pkg-config
                                                 libxml2
                                                 libxslt))
                                               (else '())))))
      (list "nss-certs" nss-certs)
      (list "gemrc" (gemrc ruby))
      (filter
       (match-lambda
         ((name rest ...)
          (not (any
                (cut string= name <>)
                '("bundler" "gemrc" "bundle-install")))))
       (package-inputs pkg)))))))

(define (extract-bundle-package-from-package pkg)
  (and=> (find (match-lambda ((name value rest ...)
                              (string=? name "bundle-install")))
               (package-inputs pkg))
         (match-lambda
           (("bundle-install" value rest ...)
            (package-source value)))))

(define (compute-bundle-package-hash bundle-pkg)
  (with-store store
    (query-path-hash store
                     (bundle-package-to-store bundle-pkg))))

(define (update-bundle-package-source bundle-pkg)
  (define (update-expression expr old-hash hash)
    ;; Update package expression EXPR, replacing occurrences of
    ;; OLD-HASH by HASH (base32 representation thereof).
    (let ((old-hash (bytevector->nix-base32-string old-hash))
          (hash     (bytevector->nix-base32-string hash)))
      (string-replace-substring expr old-hash hash)))

  (let ((new-hash (compute-bundle-package-hash bundle-pkg)))
    (if (equal? new-hash (bundle-package-hash bundle-pkg))
        #f
        (let* ((loc (bundle-package-location bundle-pkg))
               (file (and=> (location-file loc)
                            (cut search-path %load-path <>))))
          (if file
              (let ((old-hash (bundle-package-hash bundle-pkg)))
                (edit-expression
                 (assq-set! (location->source-properties loc)
                            'filename file)
                 (cut update-expression <> old-hash new-hash)))
              (begin
                (warning (G_ "~a: could not locate source file")
                         (location-file loc))
                #f))))))
