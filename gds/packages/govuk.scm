(define-module (gds packages govuk)
  #:use-module (ice-9 regex)
  #:use-module (ice-9 match)
  #:use-module (srfi srfi-1)
  #:use-module (guix packages)
  #:use-module (guix utils)
  #:use-module (guix gexp)
  #:use-module (guix build-system gnu)
  #:use-module (guix build-system guile)
  #:use-module (guix build-system trivial)
  #:use-module (guix build-system ruby)
  #:use-module (guix download)
  #:use-module (guix search-paths)
  #:use-module (guix records)
  #:use-module (guix git-download)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages admin)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages curl)
  #:use-module (gnu packages chromium)
  #:use-module (gnu packages ruby)
  #:use-module (gnu packages certs)
  #:use-module (gnu packages commencement)
  #:use-module (gnu packages guile)
  #:use-module (gnu packages gawk)
  #:use-module (gnu packages gnupg)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages python)
  #:use-module (gnu packages rails)
  #:use-module (gnu packages terraform)
  #:use-module (gnu packages databases)
  #:use-module (gnu packages xml)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages base)
  #:use-module (gnu packages tls)
  #:use-module (gnu packages node)
  #:use-module (gnu packages imagemagick)
  #:use-module (gnu packages pv)
  #:use-module (gnu packages python-web)
  #:use-module (gnu packages ssh)
  #:use-module (gnu packages sqlite)
  #:use-module (gnu packages golang)
  #:use-module (gnu packages web)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages libffi)
  #:use-module (gnu packages version-control)
  #:use-module (gnu packages rsync)
  #:use-module (gds build-system rails)
  #:use-module (gds packages guix)
  #:use-module (gds packages utils)
  #:use-module (gds packages utils bundler)
  #:use-module (gds packages govuk ruby))

(define govuk-admin-template-initialiser
  '(lambda _
     (with-output-to-file
         "config/initializers/govuk_admin_template_environment_indicators.rb"
       (lambda ()
         (display "GovukAdminTemplate.environment_style = ENV.fetch('GOVUK_ADMIN_TEMPLATE_ENVIRONMENT_STYLE', 'development')
GovukAdminTemplate.environment_label = ENV.fetch('GOVUK_ADMIN_TEMPLATE_ENVIRONMENT_LABEL', 'Development')
")))
     #t))

(define-public asset-manager
  (package-with-bundler
   (bundle-package
    (hash (base32 "0mkklc96man1pblnx1rajaa3fs4hpkqkml7k413ahyqsli433gb8")))
   (package
     (name "asset-manager")
     (version "release_372")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1jjdrhmg828ci8zjzlbcml4gys7mffmsm831wcazifshi9mx3q7r")))
     (build-system rails-build-system)
     (inputs
      `(("govuk_clamscan"
         ,
         (package
           (name "fake-govuk-clamscan")
           (version "1")
           (source #f)
           (build-system trivial-build-system)
           (arguments
            `(#:modules ((guix build utils))
              #:builder (begin
                          (use-modules (guix build utils))
                          (let
                              ((bash (string-append
                                      (assoc-ref %build-inputs "bash")
                                      "/bin/bash")))
                            (mkdir-p (string-append %output "/bin"))
                            (call-with-output-file (string-append
                                                    %output
                                                    "/bin/govuk_clamscan")
                              (lambda (port)
                                (simple-format port "#!~A\nexit 0\n" bash)))
                            (chmod (string-append %output "/bin/govuk_clamscan") #o555)
                            #t))))
           (native-inputs
            `(("bash" ,bash)))
           (synopsis "")
           (description "")
           (license #f)
           (home-page #f)))))
     (arguments
      `(#:phases
        (modify-phases %standard-phases
          (add-after 'install 'create-uploads-and-fake-s3-directories
                     (lambda* (#:key outputs #:allow-other-keys)
                       (let ((out (assoc-ref outputs "out")))
                         (mkdir-p (string-append out "/uploads"))
                         (mkdir-p (string-append out "/fake-s3")))
                       #t)))))
     (synopsis "Manages uploaded assets (e.g. PDFs, images, ...)")
     (description "The Asset Manager is used to manage assets for the GOV.UK Publishing Platform")
     (license license:expat)
     (home-page "https://github.com/alphagov/asset-manager"))
   #:extra-inputs (list libffi)))

(define-public authenticating-proxy
  (package-with-bundler
   (bundle-package
    (hash (base32 "0lcwppnjq114077mfc0pzdrdkz8api5lyq2pyk7dbrp553yaz541")))
   (package
     (name "authenticating-proxy")
     (version "release_126")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "158pjzwn6nc3y6qdw0cnnb3lzv0fyx3ylgbrgwpjfz5m2a160wc7")))
     (build-system rails-build-system)
     (arguments
      `(#:precompile-rails-assets? #f
        #:phases
        (modify-phases %standard-phases
          (add-after 'install 'replace-mongoid.yml
            ,(replace-mongoid.yml)))))
     (synopsis "Proxy to add authentication via Signon")
     (description "The Authenticating Proxy is a Rack based proxy,
written in Ruby that performs authentication using gds-sso, and then
proxies requests to some upstream")
     (license #f)
     (home-page "https://github.com/alphagov/authenticating-proxy"))))

(define-public bouncer
  (package-with-bundler
   (bundle-package
    (hash (base32 "1bsrs5a7yfg1fhypy9c83lnfgh0aknr41l8pyyjm92mp7gshjvl8")))
   (package
     (name "bouncer")
     (version "release_257")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0fc8zs1yny38gm1p1pnrpby4vkrrqjgqga4hf91b63wrifsbki9l")))
     (build-system rails-build-system)
     (arguments
      '(#:precompile-rails-assets? #f))
     (synopsis "Rack based redirector backed by the Transition service")
     (description "")
     (license license:expat)
     (home-page "https://github.com/alphagov/bouncer"))
   #:extra-inputs (list libffi postgresql)))

(define-public calculators
  (package-with-bundler
   (bundle-package
    (hash (base32 "1psxdhiidivdyl2ifward6x0689cri5i6x5ibzqawpzb9r2rbw3w")))
   (package
     (name "calculators")
     (version "release_489")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1fafyjyjzzzr502jy6wzskj91xifgxfzdkfawhv4301ivc9i4g1b")))
     (build-system rails-build-system)
     (synopsis "Calculators provides the Child benefit tax calculator")
     (description "")
     (license license:expat)
     (home-page "https://github.com/alphagov/calculators"))
   #:extra-inputs (list libffi)))

(define-public calendars
  (package-with-bundler
   (bundle-package
    (hash (base32 "13pp3j758mzb2fryq6kdzwrbc9527i8dcnvqbwsxa21n9srfdfdm")))
   (package
     (name "calendars")
     (version "release_717")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1716131ryljw8hzh1ih60m8ac0nrbas5x998pm4k7w53b27clznd")))
     (build-system rails-build-system)
     (synopsis "Serves calendars on GOV.UK")
     (description "")
     (license license:expat)
     (home-page "https://github.com/alphagov/calendars"))
   #:extra-inputs (list libffi)))

(define-public collections
  (package-with-bundler
   (bundle-package
    (hash (base32 "1jgdwkd5ilg71l4v8pn9k6qj5rqd09afrgd34xxi05p15krqiqrq")))
   (package
     (name "collections")
     (version "release_885")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "07yljx4iv8z29hpvy52dxpk0d6yd79fvvd3iy7sr52qq03y6hnni")))
     (build-system rails-build-system)
     (arguments
      '(;; jasmine-rails seems to get annoyed if it's configuration
        ;; doesn't exist in the spec directory
        #:exclude-files ("tmp")))
     (synopsis "Collections serves the new GOV.UK navigation and other pages")
     (description "")
     (license license:expat)
     (home-page "https://github.com/alphagov/collections"))
   #:extra-inputs (list libffi)))

(define-public collections-publisher
  (package-with-bundler
   (bundle-package
    (hash (base32 "0xnan8v69w4y8vb3bkfnq06ycl939vnmsqy0crgg56zw8ril6kqn")))
   (package
     (name "collections-publisher")
     (version "release_568")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "16rkggm022cvlzrfhglhg3k5g8p2fpfzxbrm78r9kqry5pp7nr1h")))
     (build-system rails-build-system)
     (arguments
      `(#:phases
        (modify-phases %standard-phases
          (add-before 'install 'add-govuk-admin-template-initialiser
            ,govuk-admin-template-initialiser)
          (add-after 'install 'replace-database.yml
                     ,(use-blank-database.yml)))))
     (synopsis "Used to create browse and topic pages")
     (description "")
     (license license:expat)
     (home-page "https://github.com/alphagov/collections-publisher"))
   #:extra-inputs (list mariadb
                        openssl
                        libffi)))

(define-public contacts-admin
  (package-with-bundler
   (bundle-package
    (hash (base32 "0rjcicw81ljs0q107a10sy5shpm6cf600dzmynbxp4yhhsska1mj")))
   (package
     (name "contacts-admin")
     (version "release_578")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "084206c597bzs7dahp7xz0r8aik9l92bgysdl8syfzbwig0nhk6i")))
     (build-system rails-build-system)
     (inputs
      `(;; hostname is needed by the redis-lock gem
        ("inetutils" ,inetutils)))
     (arguments
      `(;; The mock_organisations_api, from the spec directory is used
        ;; in development
        #:exclude-files ("tmp")
        #:phases
        (modify-phases %standard-phases
          (add-before 'install 'add-govuk-admin-template-initialiser
            ,govuk-admin-template-initialiser)
          (add-after 'install 'replace-database.yml
            ,(use-blank-database.yml)))))
     (synopsis "Used to publish organisation contact information to GOV.UK")
     (description "")
     (license license:expat)
     (home-page "https://github.com/alphagov/contacts-admin"))
   #:extra-inputs (list libffi
                        mariadb
                        openssl)))

(define-public content-audit-tool
  (package-with-bundler
   (bundle-package
    (hash (base32 "1brdpli4f3yami1i8rfb0x2dvcb00cjf46drc0b3025fwqqq4yqp")))
   (package
     (name "content-audit-tool")
     (version "release_593")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1dfv8nm7d3mdkkw3z1vlq8y1qlnswkbi2hy4hnmyj1f4d46cgaql")))
     (build-system rails-build-system)
     (arguments
      `(#:phases
        (modify-phases %standard-phases
          (add-before 'install 'add-govuk-admin-template-initialiser
            ,govuk-admin-template-initialiser)
          (add-after 'install 'replace-database.yml
                     ,(use-blank-database.yml)))))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/content-audit-tool"))
   #:extra-inputs (list postgresql libffi)))

(define-public content-data-admin
  (package-with-bundler
   (bundle-package
    (hash (base32 "0dxka147alrmhn7x4r8iv88p2vk91a7cj7wgz6l3ac6qnp4dhafd")))
   (package
     (name "content-data-admin")
     (version "release_449")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1cpzv42bf3lk3pz1jb6whnzijrhmxj0v99qiyvf8fkw2cngcvki7")))
     (build-system rails-build-system)
     (synopsis "A front end for the data warehouse")
     (description "")
     (license license:expat)
     (home-page "https://github.com/alphagov/content-data-admin"))
   #:extra-inputs (list postgresql libffi)))

(define-public content-performance-manager
  (package-with-bundler
   (bundle-package
    (hash (base32 "1nfkms4nl9izcmbdjj1w6qy459c98d7j1sljfbzhqs9sncpkwxs8")))
   (package
     (name "content-performance-manager")
     (version "release_1044")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "13ydnavz79qxyqzwk7z8m1mklmafp8nj34bkff1bzy1fa8qnp6fs")))
     (build-system rails-build-system)
     (arguments
      `(#:phases
        (modify-phases %standard-phases
          (add-before 'install 'add-govuk-admin-template-initialiser
            ,govuk-admin-template-initialiser)
          (add-after 'install 'replace-database.yml
                     ,(use-blank-database.yml)))))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/content-performance-manager"))
   #:extra-inputs (list postgresql libffi)))

(define-public content-publisher
  (package-with-bundler
   (bundle-package
    (hash (base32 "1974wr1vi12mgi7jdan8ivdv6l2zbmqs7y26qpjlrdl32hrdbarl")))
   (package
     (name "content-publisher")
     (version "release_899")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1ji5ns4251zj5aq1gvpk78rsj7vwfc3iqv0p51nspvl0rm8f85w9")))
     (build-system rails-build-system)
     (arguments
      `(;; TODO: Asset precompilation is now failing, due to npm not
        ;; being used to download some JavaScript.
        #:precompile-rails-assets? #f
        #:phases
        (modify-phases %standard-phases
         (add-before 'precompile-rails-assets 'set-fake-SECRET_KEY_BASE
          (lambda _
            ;; TODO: Active Storage seems to require the
            ;; SECRET_KEY_BASE Not sure why, so set a fake one to make
            ;; asset precompilation work
            (setenv "SECRET_KEY_BASE" "fake")
            ;; assets:precompile seems to fail without the
            ;; JWT_AUTH_SECRET being set
            (setenv "JWT_AUTH_SECRET" "fake")))
         (add-after 'install 'replace-database.yml
          ,(use-blank-database.yml)))))
     (synopsis "")
     (description "")
     (license license:expat)
     (home-page "https://github.com/alphagov/content-publisher"))
   #:extra-inputs (list libffi
                        postgresql)))

(define-public content-store
  (package-with-bundler
   (bundle-package
    (hash (base32 "1mpir26zzsc83z94yqfi18n67wd6pgn5n42n5p1absp429bdmkza")))
   (package
     (name "content-store")
     (version "release_868")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1n13iqqa4fkpk3hry207pa397m3j00ygff6scc9cfddjvbsimilp")))
     (build-system rails-build-system)
     (arguments '(#:precompile-rails-assets? #f))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/content-store"))
   #:extra-inputs (list libffi)))

(define-public content-tagger
  (package-with-bundler
   (bundle-package
    (hash (base32 "0agqbvws4ibidx8kmy6j5rz1fw1ryl22vcjr4y7svrnl8634wnx9")))
   (package
     (name "content-tagger")
     (version "release_951")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "19qyq7whpsl46gqa0v9rirn6mmh8xyd2hc41j0i7lj5j7xlvm9nc")))
     (build-system rails-build-system)
     (arguments
      `(#:phases
        (modify-phases %standard-phases
          (add-before 'install 'add-govuk-admin-template-initialiser
            ,govuk-admin-template-initialiser)
          (add-after 'install 'replace-database.yml
                     ,(use-blank-database.yml)))))

     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/content-tagger"))
   #:extra-inputs (list postgresql
                        libffi)))

(define-public email-alert-api
  (package-with-bundler
   (bundle-package
    (hash (base32 "09s95nbrv20bmkjq9cp7hkx4xr8bd36ac30gxz5yws4jibnrf38d")))
   (package
     (name "email-alert-api")
     (version "release_797")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0r2f2bbb9ww3jwhwz35pbmkn7yrdx92x1pm9k7984ad6ycq0rsbd")))
     (build-system rails-build-system)
     (arguments
      `(#:precompile-rails-assets? #f
        #:phases
        (modify-phases %standard-phases
          (add-after 'install 'replace-database.yml
                     ,(use-blank-database.yml)))))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/email-alert-api"))
   #:extra-inputs (list libffi postgresql)))

(define-public email-alert-frontend
  (package-with-bundler
   (bundle-package
    (hash (base32 "16pdkahmp49a10i9q4m9zfiv65rbj9zi3v5anbb7lafmnq8byy83")))
   (package
     (name "email-alert-frontend")
     (version "release_356")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "104sb2ksa76zvla756f49a96ckry7py9srphcgkwfqgg29wvia1j")))
     (build-system rails-build-system)
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/email-alert-frontend"))
   #:extra-inputs (list libffi)))

(define-public email-alert-service
  (package-with-bundler
   (bundle-package
    (hash (base32 "0ymywq81si7xs45hywgswb6ps2lsqnqgxkb80gsa9dq65gvqsbb2")))
   (package
     (name "email-alert-service")
     (version "release_236")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "16znx72n9ffd14016mpqmw06qrbsack5hfgcm300lc67xl6dcics")))
     (build-system gnu-build-system)
     (inputs
      `(("ruby" ,ruby)))
     (arguments
      `(#:phases
        (modify-phases %standard-phases
          (replace 'configure (lambda args #t))
          (replace 'build (lambda args #t))
          (replace 'check (lambda args #t))
          (replace 'install
                   (lambda* (#:key inputs outputs #:allow-other-keys)
                     (let* ((out (assoc-ref outputs "out")))
                       (copy-recursively
                        "."
                        out
                        #:log (%make-void-port "w")))))
          (add-after 'patch-bin-files 'wrap-with-relative-path
                     (lambda* (#:key outputs #:allow-other-keys)
                       (let* ((out (assoc-ref outputs "out")))
                         (substitute* (find-files
                                       (string-append out "/bin"))
                           (((string-append out "/bin"))
                            "${BASH_SOURCE%/*}"))))))))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/email-alert-service/"))
   #:extra-inputs (list libffi)))

(define-public feedback
  (package-with-bundler
   (bundle-package
    (hash (base32 "1ps5c95jjz46ml26qqn0hrkhjnh65x2qb31z4h94rnvzwdpfmfxs")))
   (package
     (name "feedback")
     (version "release_662")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "03kk4y2azqp8yvjnd026y5d3ab00w2p3vxg2m7vj7vs88wa86xj8")))
     (build-system rails-build-system)
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/feedback"))
   #:extra-inputs (list libffi)))

(define-public finder-frontend
  (package-with-bundler
   (bundle-package
    (hash (base32 "022vv5xhbw6zh7arlnpdphddf3043ck19bh03626avqkc9v8zbws")))
   (package
     (name "finder-frontend")
     (version "release_969")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1y21zkp9nq0maswsc9gwjjs89n6c7ljyawxsmdxqxdhk6nmb9aar")))
     (build-system rails-build-system)
     (arguments
      '(;; jasmine-rails seems to get annoyed if it's configuration
        ;; doesn't exist in the spec directory
        #:exclude-files ("tmp")))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/finder-frontend"))
   #:extra-inputs (list libffi)))

(define-public frontend
  (package-with-bundler
   (bundle-package
    (hash (base32 "0bsqrdws6ckzl0qna8vl92bapkqaz98gsqv737nqcb479gzqh6xj")))
   (package
     (name "frontend")
     (version "release_3142")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0lm3hcpwwi5aadnnqfvv4gy5v67r4hia79nv3y486bgahnz1vlxa")))
     (build-system rails-build-system)
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/frontend"))
   #:extra-inputs (list libffi)))

(define-public government-frontend
  (package-with-bundler
   (bundle-package
    (hash (base32 "127czhzgsz6cswladh2jvl5sg43wspg8ickz7k5lpi9kcrf8k5pg")))
   (package
     (name "government-frontend")
     (version "release_1089")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1frgzp1sl39s5brwz9p1zw6iaid76nnk9havwqkr6xmv34vc0slr")))
     (build-system rails-build-system)
     (arguments
      '(;; jasmine-rails seems to get annoyed if it's configuration
        ;; doesn't exist in the spec directory
        #:exclude-files ("tmp")))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/government-frontend"))
   #:extra-inputs (list libffi)))

(define-public govuk-content-schemas
  (package
    (name "govuk-content-schemas")
    (version "release_875")
    (source
     (github-archive
      #:repository name
      #:commit-ish version
      #:hash (base32 "0r2sf2gmdr33q0bq7rwxx1ysg2b2nql2wcrsl12i2a46hf6ip6wk")))
    (build-system gnu-build-system)
    (arguments
     `(#:phases
       (modify-phases %standard-phases
         (delete 'configure)
         (delete 'build)
         (delete 'check)
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out")))
               (copy-recursively "." out)
               #t))))))
    (synopsis "govuk-content-schemas")
    (description "govuk-content-schemas")
    (license #f)
    (home-page #f)))

(define-public govuk-setenv
  (package
   (name "govuk-setenv")
   (version "1")
   (source #f)
   (build-system trivial-build-system)
   (arguments
    `(#:modules ((guix build utils))
      #:builder (begin
                  (use-modules (guix build utils))
                  (let
                      ((bash (string-append
                              (assoc-ref %build-inputs "bash")
                              "/bin/bash"))
                       (sudo (string-append
                              (assoc-ref %build-inputs "sudo")
                              "/bin/sudo")))
                    (mkdir-p (string-append %output "/bin"))
                    (call-with-output-file (string-append
                                            %output
                                            "/bin/govuk-setenv")
                      (lambda (port)
                        (simple-format port "#!~A
set -exu
APP=\"$1\"
shift
source \"/tmp/env.d/$APP\"
cd \"/var/apps/$APP\"
~A --preserve-env -u \"$APP\" \"$@\"
" bash sudo)))
                    (chmod (string-append %output "/bin/govuk-setenv") #o555)
                    #t))))
   (native-inputs
    `(("bash" ,bash)
      ("sudo" ,sudo)))
   (synopsis "govuk-setenv script for running commands in the service environment")
   (description "This script runs the specified command in an
environment similar to that which the service is running. For example,
running govuk-setenv @code{publishing-api rails console} runs the
@code{rails console} command as the user associated with the
Publishing API service, and with the environment variables for this
service setup.")
   (license #f)
   (home-page #f)))

(define-public govuk-guix
  (package
    (name "govuk-guix")
    (version "release_3")
    (source
     (github-archive
      #:repository name
      #:commit-ish version
      #:hash (base32 "1g714x476g1b73rjfkxk8av8jcb4r7ql39c1d5pa7zjn45ndc14a")))
    (build-system guile-build-system)
    (inputs
     `(("coreutils" ,coreutils)
       ("bash" ,bash)
       ("guix" ,guix)
       ("guile" ,guile-2.2)
       ("guile-gcrypt" ,guile-gcrypt)
       ("awscli" ,awscli)
       ("gawk" ,gawk)
       ("grep" ,grep)
       ("ruby" ,ruby)
       ("pv" ,pv)
       ("pigz" ,pigz)
       ("xz" ,xz)))
    (arguments
     '(#:phases
       (modify-phases %standard-phases
         (add-before 'build 'set-GUILE_WARN_DEPRECATED
           (lambda _
             (setenv "GUILE_WARN_DEPRECATED" "detailed")
             #t))
         (add-after 'build 'install-bin
           (lambda* (#:key inputs outputs #:allow-other-keys)
             (let ((out (assoc-ref outputs "out")))
               (install-file "bin/govuk" (string-append out "/bin"))
               (for-each (lambda (file)
                           (install-file
                            file
                            (string-append  out "/share/govuk-guix/bin")))
                         (find-files "bin")))
             #t))
         (add-after 'install 'wrap-bin-files
           (lambda* (#:key inputs outputs #:allow-other-keys)
             (use-modules (ice-9 rdelim)
                          (ice-9 popen))
             (let* ((out (assoc-ref outputs "out"))
                    (effective (read-line
                                (open-pipe* OPEN_READ
                                            "guile" "-c"
                                            "(display (effective-version))")))
                    (module-dir (string-append out "/share/guile/site/"
                                               effective)))

               (copy-recursively
                "gds/systems/govuk/skeletons"
                (string-append module-dir
                               "/gds/systems/govuk/skeletons"))

               (wrap-program (string-append out "/bin/govuk")
                 `("PATH" prefix (,(string-append
                                    (assoc-ref inputs "coreutils")
                                    "/bin")
                                  ,(string-append
                                    (assoc-ref inputs "guile")
                                    "/bin")
                                  ,(string-append
                                    (assoc-ref inputs "bash") "/bin")))
                 `("GUILE_LOAD_COMPILED_PATH" =
                   (,(getenv "GUILE_LOAD_COMPILED_PATH")))
                 `("GUILE_LOAD_PATH" = (,(string-append
                                          (getenv "GUILE_LOAD_PATH")
                                          ":"
                                          module-dir)))
                 `("GOVUK_EXEC_PATH" suffix
                   (,(string-append out "/share/govuk-guix/bin")))
                 `("GUIX_UNINSTALLED" = ("true")))

               (wrap-program (string-append
                              out "/share/govuk-guix/bin/govuk-aws")
                 `("PATH" =
                   ,(map (lambda (input)
                           (string-append (assoc-ref inputs input) "/bin"))
                         (list "coreutils" "awscli" "ruby" "gawk" "grep"))))

               (wrap-program
                   (string-append out
                                  "/share/govuk-guix/bin/govuk-download-backups")
                 `("PATH" prefix
                   ,(map (lambda (input)
                           (string-append (assoc-ref inputs input) "/bin"))
                         (list "awscli" "ruby" "pv" "pigz" "xz")))))

             #t)))))
    (home-page "https://github.com/alphagov/govuk-guix")
    (synopsis "Package, service and system definitions for GOV.UK")
    (description "")
    (license #f)))

(define-public (current-govuk-guix)
  (let* ((repository-root (canonicalize-path
                           (string-append (current-source-directory)
                                          "/../..")))
         (select? (delay (git-predicate repository-root))))
    (package
      (inherit govuk-guix)
      (version (string-append (package-version govuk-guix)
                              "-snapshot"))
      (source (local-file repository-root "govuk-guix-current"
                          #:recursive? #t
                          #:select? (force select?))))))

(define-public hmrc-manuals-api
  (package-with-bundler
   (bundle-package
    (hash (base32 "18dyiqzqi9m7xhz4v47lf63ryndfa6f2j4da5ngkzkl232nl4kc0")))
   (package
     (name "hmrc-manuals-api")
     (version "release_341")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0xq53d4fhp80a137vddvmkhmyd2cba3jj73zbxf67x4kbas83vzb")))
     (build-system rails-build-system)
     (arguments `(#:precompile-rails-assets? #f))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/hmrc-manuals-api"))
   #:extra-inputs (list libffi)))

(define-public imminence
  (package-with-bundler
   (bundle-package
    (hash (base32 "0fm1v7bhgi5j4lr7l5dlhhbh5waw5bjjs03z5f3p9cpij62q9bai")))
   (package
     (name "imminence")
     (version "release_516")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "05wb703whx6s8srkjspwgnvr6yfhmf3rqdjpqhwhp7mj16lwmy06")))
     (build-system rails-build-system)
     (arguments
      `(#:phases
        (modify-phases %standard-phases
                       (add-after 'install 'replace-mongoid.yml
                                  ,(replace-mongoid.yml)))))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/imminence"))
   #:extra-inputs (list libffi)))

(define-public info-frontend
  (package-with-bundler
   (bundle-package
    (hash (base32 "063zkgnv9105hkcysqsxwcjx088vxkr136fllv4fd46dfc09y33p")))
   (package
     (name "info-frontend")
     (version "release_349")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1wg7ii341d6jxq0cgxkr1jlmsxi3n4sc0czzrx8c2h8m1v8h1dia")))
     (build-system rails-build-system)
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/info-frontend"))
   #:extra-inputs (list libffi)))

(define-public licence-finder
  (package-with-bundler
   (bundle-package
    (hash (base32 "06axnr1h09qwpaz6xlavdix459f5immzgn3vff7bhp9747dzg8my")))
   (package
     (name "licence-finder")
     (version "release_581")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0f9liz2c6hknbl21j23cdvw46f3cdxjd16r9j67hk8l3aqxr96x9")))
     (build-system rails-build-system)
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/licence-finder"))
   #:extra-inputs (list libffi)))

(define-public link-checker-api
  (package-with-bundler
   (bundle-package
    (hash (base32 "0z8bm4264rn9qavbcy2f3f1904zr69fazqjypsv7rq5yj9bbq5bb")))
   (package
     (name "link-checker-api")
     (version "release_204")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "194cmn4fbzjvnsqwh1si0crq8siwkkm4i7hmadxgh19wxrj766ix")))
     (build-system rails-build-system)
     (arguments
      `(#:precompile-rails-assets? #f))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/link-checker-api"))
   #:extra-inputs (list postgresql libffi
                        ;; TODO: Remove sqlite once it's been removed
                        ;; from the package
                        sqlite)))

(define-public local-links-manager
  (package-with-bundler
   (bundle-package
    (hash (base32 "1xq72rhwh93mgfkrfwvagc8nzf4iw67ixr0ah4y97ri6cppf8kh8")))
   (package
     (name "local-links-manager")
     (version "release_358")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "10x38snl8l4s5k7v2gf2942zxdkxlkgy3l3cvplhwnvzcxzgc0mv")))
     (build-system rails-build-system)
     (inputs
      `(;; hostname is needed by the redis-lock gem
        ("inetutils" ,inetutils)))
     (arguments
      `(#:phases
        (modify-phases %standard-phases
          (add-before 'install 'add-govuk-admin-template-initialiser
            ,govuk-admin-template-initialiser)
          (add-after 'install 'replace-database.yml
            ,(use-blank-database.yml)))))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/local-links-manager"))
   #:extra-inputs (list postgresql
                        libffi)))

(define-public manuals-frontend
  (package-with-bundler
   (bundle-package
    (hash (base32 "047bi8kg2nc3a180l4bm3kvy04avhwkrbqj4631yhsa812nmymjs")))
   (package
     (name "manuals-frontend")
     (version "release_507")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0dhvvc6szi099f9c41pnp3l2spm37r5qwr5lvjfbgncyhxhqdklj")))
     (build-system rails-build-system)
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/manuals-frontend"))
   #:extra-inputs (list libffi)))

(define-public manuals-publisher
  (package-with-bundler
   (bundle-package
    (hash (base32 "07n7p39ypvyr1gvgkjyx2hm3m7sa8n0482bk174cq2acplz92m2z")))
   (package
     (name "manuals-publisher")
     (version "release_1195")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0h588ycr7y1jdanl2x5hbk8wj8jx0ilwfqw9sbz5i7ikn642k8br")))
     (build-system rails-build-system)
     (arguments
      `(#:phases
        (modify-phases %standard-phases
          (add-before 'install 'add-govuk-admin-template-initialiser
            ,govuk-admin-template-initialiser)
          (add-after
              'install 'alter-secrets.yml
            (lambda* (#:key outputs #:allow-other-keys)
              (substitute* (string-append
                            (assoc-ref outputs "out")
                            "/config/secrets.yml")
                (("SECRET_TOKEN")
                 "SECRET_KEY_BASE")))))
        ;; jasmine-rails seems to get annoyed if it's configuration
        ;; doesn't exist in the spec directory
        #:exclude-files ("tmp")))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/manuals-publisher"))
   #:extra-inputs (list libffi)))

(define-public maslow
  (package-with-bundler
   (bundle-package
    (hash (base32 "0rfqq45zcdc3f67ri5jfr48bxy8wy3ws9gxz79bk92f28n86p714")))
   (package
     (name "maslow")
     (version "release_411")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1i59khcba1g0ff4nry469k7kkf8yrphj64c2yfflvv3b1a106w4j")))
     (build-system rails-build-system)
     (arguments
      `(#:phases
        (modify-phases %standard-phases
          (add-before 'install 'add-govuk-admin-template-initialiser
            ,govuk-admin-template-initialiser)
          (add-after 'install 'replace-mongoid.yml
                     ,(replace-mongoid.yml))
          (add-after 'replace-mongoid.yml 'replace-gds-sso-initializer
                     ,(replace-gds-sso-initializer)))))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/maslow"))
   #:extra-inputs (list libffi)))

(define-public organisations-publisher
  (package-with-bundler
   (bundle-package
    (hash (base32 "0x4jgvdikiwyw7apir2l0ax82x705m48b4xl6alq8f0wnjpa0fqv")))
   (package
     (name "organisations-publisher")
     (version "release_8")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "11wyclj4l89176svwxblky10lzbqymwm7sy8dkc0d945j30kb7sy")))
     (build-system rails-build-system)
     (synopsis "")
     (description "")
     (license license:expat)
     (home-page "https://github.com/alphagov/organisations-publisher"))
   #:extra-inputs (list libffi postgresql
                        ;; TODO Remove sqlite if it's unused, it's still in the Gemfile
                        sqlite)))

(define-public mini-environment-admin
  (package
    (name "govuk-mini-environment-admin")
    (version "release_10")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://git.cbaines.net/gds/govuk-mini-environment-admin")
             (commit version)))
       (file-name (git-file-name name version))
       (sha256
        (base32
         "0axgw29j545v2w6dpf9jrh6n9v5bs61rf24lxvc59hk0abscw26v"))))
    (build-system rails-build-system)
    (arguments
     '(#:phases
       (modify-phases %standard-phases
         (delete 'replace-git-ls-files)
         (add-after 'install 'use-relative-config-file
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out")))
               (substitute* (string-append out "/bin/rails")
                 (("\\.\\.\\/config")
                  (string-append out "/config"))))))
         (delete 'wrap-bin-files-for-rails)
         (delete 'wrap-with-relative-path)
         (add-after 'install 'wrap-bin/rails
           (lambda* (#:key inputs outputs #:allow-other-keys)
             ((@@ (guix build ruby-build-system) wrap-ruby-program)
              (string-append (assoc-ref outputs "out") "/bin/rails")
              ;; Terraform doesn't support a search path for plugins,
              ;; and expects a single directory, so just lump together
              ;; everything which is used via the PATH in to one
              ;; input.
              `("PATH" prefix (,(string-append (assoc-ref
                                                inputs "PATH-dependencies")
                                               "/bin")))
              `("GEM_PATH" prefix (,(getenv "GEM_PATH"))))
             (substitute* (string-append (assoc-ref outputs "out")
                                         "/bin/.real/rails")
               (("../config") "../../config"))
             (substitute* (string-append (assoc-ref outputs "out")
                                         "/bin/rails")
               (((assoc-ref outputs "out")) ".")))))))
    (inputs
     `(("ruby-rails" ,ruby-rails)
       ("ruby-sass-rails" ,ruby-sass-rails)
       ("ruby-listen" ,ruby-listen)
       ("ruby-web-console" ,ruby-web-console)
       ("ruby-pg" ,ruby-pg)
       ("ruby-gds-sso" ,ruby-gds-sso)
       ("ruby-govuk-admin-template" ,ruby-govuk-admin-template)
       ("ruby-plek" ,ruby-plek)
       ("ruby-terraform"
        ,(package
           (inherit ruby-terraform)
           (arguments
            (substitute-keyword-arguments
                (package-arguments ruby-terraform)
              ((#:phases phases '%standard-phases)
               `(modify-phases ,phases
                  (replace 'replace-git-ls-files
                    (lambda _
                      (substitute* "ruby_terraform.gemspec"
                        (("`git ls-files -z`") "`find . -type f -print0`"))))))))
           (source
            (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://github.com/cbaines/ruby_terraform.git")
                    ;; hash for the support-passing-target-to-destroy branch
                    (commit "b858f9d7b1a5c193b94bd4bf38eea5fc3afd0295")))
              (sha256
               (base32
                "0714zhc0rak2wrb2yivy7a1naqlcccwgd90lp2vpjs7aj3j23i2k"))))))
       ("ruby-que" ,ruby-que)
       ("ruby-with-advisory-lock" ,ruby-with-advisory-lock)
       ("ruby-git" ,ruby-git)
       ("PATH-dependencies"
        ,(directory-union
          "govuk-mini-environment-admin-path-dependencies"
          (list postgresql
                openssh
                terraform
                (package
                  (inherit terraform-provider-libvirt)
                  (source
                   (origin
                     (method git-fetch)
                     (uri (git-reference
                           (url "http://git.cbaines.net/terraform-provider-libvirt")
                           ;; hash for the for-govuk-mini-environment-admin branch
                           (commit "682f8a9865fe0bec16423f63018725f5b364659b")))
                     (sha256
                      (base32
                       "1wxiyfkmvflf6c669h6i9ym21r5w4mw55jiy6gma3cddlbhpjhhb")))))
                terraform-provider-template
                terraform-provider-aws
                terraform-provider-local)))))
    (native-inputs
     `(("ruby-rubocop" ,ruby-rubocop)
       ("python" ,python)
       ("ruby-mocha" ,ruby-mocha)
       ;; ("coala" ,coala)
       ;; ("coala-bears" ,coala-bears)
       ))
    (synopsis "Manage mini GOV.UK environments")
    (description
     "The GOV.UK Mini Environment Admin is a web application for
managing small isolated GOV.UK deployments.  The services to run, and
data to use can be selected, and multiple backends are supported.")
    (home-page "https://git.cbaines.net/gds/govuk-mini-environment-admin/about/")
    (license license:agpl3+)))

(define-public publisher
  (package-with-bundler
   (bundle-package
    (hash (base32 "10mf2f1mjcgkmi5maig2c5bjmr9lzqh2zmjcwh7fj8xl5yqla5af")))
   (package
     (name "publisher")
     (version "release_2131")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0vaiwnbgywf905mg935fmmm9bzfky09x4lpdpnqsaq4h1nywfy3w")))
     (build-system rails-build-system)
     (arguments
      `(#:phases
        (modify-phases %standard-phases
          (add-before 'install 'add-govuk-admin-template-initialiser
            ,govuk-admin-template-initialiser)
          (add-after 'install 'replace-mongoid.yml
                     ,(replace-mongoid.yml))
          (add-after 'replace-mongoid.yml 'replace-gds-sso-initializer
                     ,(replace-gds-sso-initializer)))))
     (inputs
      `(;; hostname is needed by the redis-lock gem
        ("inetutils" ,inetutils)))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/publisher"))
   #:extra-inputs (list libffi)))

(define-public publishing-api
  (package-with-bundler
   (bundle-package
    (hash (base32 "0qxgxz42gbdic1r3mnrl9h8vb9fcnn2qwmr1bjn09r1shkc54lfw")))
   (package
     (name "publishing-api")
     (version "release_1404")
     (source
      (github-archive
       #:repository "publishing-api"
       #:commit-ish version
       #:hash (base32 "1rhl0p10viwp8zqryggx6dx7wniv9md0a8hy6rdk6csknbcz4247")))
     (build-system rails-build-system)
     (arguments '(#:precompile-rails-assets? #f))
     (synopsis "Service for storing and providing workflow for GOV.UK content")
     (description
      "The Publishing API is a service that provides a HTTP API for
managing content for GOV.UK.  Publishing applications can use the
Publishing API to manage their content, and the Publishing API will
populate the appropriate Content Stores (live or draft) with that
content, as well as broadcasting changes to a message queue.")
     (license license:expat)
     (home-page "https://github.com/alphagov/publishing-api"))
   #:extra-inputs (list
                   libffi
                   ;; Required by the pg gem
                   postgresql)))

(define-public publishing-e2e-tests
  (package-with-bundler
   (bundle-package
    (hash
     (base32 "0v0ywf7685mfdj7axz43wb8n3r943d5ys0jrzjzbc5dh97cdpaka")))
   (package
     (name "publishing-e2e-tests")
     (version "0")
     (source
      (github-archive
       #:repository "publishing-e2e-tests"
       #:commit-ish "58ee6e4190d9b0d0316b2635f1c7944ce6118fc1"
       #:hash (base32 "14nn0czyrxhhbciv85y7nfajh6dhp670p29qw6zwmcsz9dng68xr")))
     (build-system gnu-build-system)
     (inputs
      `(("ruby" ,ruby)
        ("chromium" ,ungoogled-chromium)))
     (arguments
      `(#:phases
        (modify-phases %standard-phases
          (replace 'configure (lambda args #t))
          (replace 'build (lambda args #t))
          (replace 'check (lambda args #t))
          (replace 'install
                   (lambda* (#:key inputs outputs #:allow-other-keys)
                     (let* ((out (assoc-ref outputs "out")))
                       (copy-recursively
                        "."
                        out
                        #:log (%make-void-port "w"))
                       (mkdir-p (string-append out "/tmp/results"))))))))
     (synopsis "Suite of end-to-end tests for GOV.UK")
     (description "")
     (license license:expat)
     (home-page "https://github.com/alphagov/publishing-e2e-tests"))
   #:extra-inputs (list
                   libffi
                   ;; For nokogiri
                   pkg-config
                   libxml2
                   libxslt)))

(define-public release
  (package-with-bundler
   (bundle-package
    (hash (base32 "0sj6zcsxdh6z4q93d7lmvwplq1nwinrz2bg3i2kiccp0hbz3v0vh")))
   (package
     (name "release")
     (version "release_435")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1zapmxhncrnfz2p9nwyq8a23pjd5gzbfh3ykc9srk80dpxpihqy6")))
     (build-system rails-build-system)
     (arguments
      `(#:phases
        (modify-phases %standard-phases
          (add-before 'install 'add-govuk-admin-template-initialiser
            ,govuk-admin-template-initialiser)
          (add-after 'install 'replace-database.yml
                     ,(use-blank-database.yml)))))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/release"))
   #:extra-inputs (list mariadb
                        openssl
                        libffi)))

(define-public router
  (package
    (name "router")
    (version "release_188")
    (source
     (github-archive
      #:repository name
      #:commit-ish version
      #:hash (base32 "1lj50pgprpprvf52djq1i59j64fkmxh50m710wgv186f8bjm3cgb")))
    (build-system gnu-build-system)
    (native-inputs
     `(("go" ,go)))
    (arguments
     `(#:phases
       (modify-phases %standard-phases
         (delete 'configure)
         (delete 'install)
         (delete 'check)
         (replace 'build
                  (lambda* (#:key inputs outputs #:allow-other-keys)
                    (let* ((out (assoc-ref outputs "out"))
                           (cwd (getcwd)))
                      (copy-recursively cwd "../router-copy")
                      (mkdir-p "__build/src/github.com/alphagov")
                      (mkdir-p "__build/bin")
                      (setenv "GOPATH" (string-append cwd "/__build"))
                      (setenv "BINARY" (string-append cwd "/router"))
                      (rename-file "../router-copy"
                                   "__build/src/github.com/alphagov/router")
                      (and
                       (with-directory-excursion
                           "__build/src/github.com/alphagov/router"
                         (and
                          (zero? (system*
                                  "make" "build"
                                          (string-append "RELEASE_VERSION="
                                                         ,version)))
                          (mkdir-p (string-append out "/bin"))))
                       (begin
                         (copy-file "router"
                                    (string-append out "/bin/router"))
                         #t))))))))
    (synopsis "")
    (description "")
    (license "")
    (home-page "https://github.com/alphagov/router")))

(define-public router-api
  (package-with-bundler
   (bundle-package
    (hash (base32 "1kk2yzl12ih7wxbmzg8bxq9h8w92qrlyvwbi5nbd1jsm070fc7bz")))
   (package
     (name "router-api")
     (version "release_219")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1j421a63zqmmfrk6xcdzn60r782aql93yxh3jflb7ips69nc0sag")))
     (build-system rails-build-system)
     (arguments '(#:precompile-rails-assets? #f))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/router-api"))
   #:extra-inputs (list libffi)))

(define-public search-admin
  (package-with-bundler
   (bundle-package
    (hash (base32 "1arv6mq3ywhjhscip9cac6ly6qkqp081ag4jjw7a9r1c9dins6f4")))
   (package
     (name "search-admin")
     (version "release_258")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "05fnbvqxxhshczw17m9qypjf1ln4a76rcyw7ylqxqkzmdcb50ncb")))
     (build-system rails-build-system)
     (arguments
      `(#:phases
        (modify-phases %standard-phases
          (add-before 'install 'add-govuk-admin-template-initialiser
            ,govuk-admin-template-initialiser))))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/search-admin"))
   #:extra-inputs (list libffi
                        mariadb
                        openssl)))

(define-public search-api
  (package-with-bundler
   (bundle-package
    (hash (base32 "12rpnii0j0jyrhpdsjx91i1zvvbml0ndcmlyc6m7nb294nf1dg7i")))
   (package
     (name "search-api")
     (version "release_2028")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0cj84w1wncq5g4gx297b35srld32pmmf5jg35i98v13bwgaw3j97")))
     (build-system rails-build-system)
     (arguments '(#:precompile-rails-assets? #f))
     (synopsis "Search API for GOV.UK")
     (description "")
     (license license:expat)
     (home-page "https://github.com/alphagov/search-api"))
   #:extra-inputs (list libffi)))

(define-public service-manual-frontend
  (package-with-bundler
   (bundle-package
    (hash (base32 "0y23xasizpa1y9882k6ppwpqvgar5lb7fkhhycp1jfp6xazhdavd")))
   (package
     (name "service-manual-frontend")
     (version "release_333")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "16qn7h686lw9hy5y4cdzbyr8qjwswfsi7v8ldjqj74kpx2cdxrnh")))
     (build-system rails-build-system)
     (arguments
      '(;; jasmine-rails seems to get annoyed if it's configuration
        ;; doesn't exist in the spec directory
        #:exclude-files ("tmp")))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/service-manual-frontend"))
   #:extra-inputs (list libffi)))

(define-public service-manual-publisher
  (package-with-bundler
   (bundle-package
    (hash (base32 "0had6irnvjyvbdwy43zg0isyh6vzlxbf38akxc9880hd7676zvpr")))
   (package
     (name "service-manual-publisher")
     (version "release_493")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1wgp0srgvm20a4w6lah1wn9gg3j3k5qf3pzffhw0gc5z1qx4kl60")))
     (build-system rails-build-system)
     (arguments
      `(#:phases
        (modify-phases %standard-phases
          (add-before 'install 'add-govuk-admin-template-initialiser
            ,govuk-admin-template-initialiser))))
     (inputs
      `(;; Loading the database structure uses psql
        ("postgresql" ,postgresql)))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/service-manual-publisher"))
   #:extra-inputs (list libffi
                        postgresql)))

(define-public short-url-manager
  (package-with-bundler
   (bundle-package
    (hash (base32 "02n6p5nx3ay5b47dm4kwvcr80a419sr9lnidf5m5yhy7dyhpiq3h")))
   (package
     (name "short-url-manager")
     (version "release_307")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0rpk4p3kxkgkkv7vlj3wic29cigvai6q8ihdzc0wpsd2rc1pqrhf")))
     (build-system rails-build-system)
     (arguments
      `(#:phases
        (modify-phases %standard-phases
          (add-after 'unpack 'patch-gds_sso-initializer
            (lambda _
              ;; TODO: Disable the creation of the development user,
              ;; as this breaks asset precompilation
              (substitute* "config/initializers/gds_sso.rb"
                (("if Rails\\.env\\.development\\?")
                 "if Rails.env.development? and false"))
              #t))
          (add-before 'precompile-rails-assets 'set-production-rails-environment
            (lambda _
              ;; Short URL Manager attempts to create a 'Test User' when
              ;; running in development, which causes asset
              ;; precompilation to break
              (setenv "RAILS_ENV" "test")
              #t))
          (add-before 'install 'add-govuk-admin-template-initialiser
            ,govuk-admin-template-initialiser))))
     (inputs
      `(;; hostname is needed by the redis-lock gem
        ("inetutils" ,inetutils)))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/short-url-manager"))
   #:extra-inputs (list libffi)))

(define-public signon
  (package-with-bundler
   (bundle-package
    (hash (base32 "0c4ifxrm69nhnhchkig61inqqf48wc3fj16mlr7mqxrrgi0lmpj7"))
    (without '("development" "test")))
   (package
     (name "signon")
     (version "release_1269")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1js3592f7435p68fgfskgvf9kz2mc7bya9rzh9p0ggvr9ifzcr7m")))
     (build-system rails-build-system)
     (arguments
      `(#:phases
        (modify-phases %standard-phases
          (add-before 'precompile-rails-assets 'set-dummy-devise-environment
            (lambda _
              (setenv "DEVISE_PEPPER" "dummy-govuk-guix-value")
              (setenv "DEVISE_SECRET_KEY" "dummy-govuk-guix-value")
              #t))
          (add-before 'install 'add-govuk-admin-template-initialiser
            ,govuk-admin-template-initialiser)
          ;; Ideally this would be configurable, but as it's not, lets
          ;; just disable it
          (add-before 'install 'disable-google-analytics
            (lambda _
              (substitute* "config/initializers/govuk_admin_template.rb"
                (("false") "true"))))
          (add-after 'install 'replace-database.yml
                     ,(use-blank-database.yml)))))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/signon"))
   #:extra-inputs (list libffi
                        mariadb
                        postgresql
                        openssl)))

(define-public smart-answers
  (package-with-bundler
   (bundle-package
    (hash (base32 "0hdpy0j6qg18czxw8nc5adyi20ya7zcxyv611c096v6a77c0lqdh")))
   (package
     (name "smart-answers")
     (version "release_4333")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "05wclvqy14iivjvzk5sa4fwxam7c7psgbmy4rj03bhj80zzh60i4")))
     (build-system rails-build-system)
     ;; Asset precompilation fails due to the preload_working_days
     ;; initialiser
     (arguments
      '(#:precompile-rails-assets? #f
        #:phases
        (modify-phases %standard-phases
          (add-before 'install 'delete-test
            (lambda _
              ;; This directory is large, ~50,000 files, so remove it
              ;; from the package to save space
              (delete-file-recursively "test"))))))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/smart-answers"))
   #:extra-inputs (list libffi)))

(define-public specialist-publisher
  (package-with-bundler
   (bundle-package
    (hash (base32 "0lx2yd6byba5hpjkdpxjxw90wv9pdl7yya5yll12y8vnr450i2ah"))
    (without '("development" "test")))
   (package
     (name "specialist-publisher")
     (version "release_1143")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1ny564aydvh8dw0z5x6w2wgf24n2hw9z4dm5fqzbdgb2i4dw0kak")))
     (build-system rails-build-system)
     (arguments
      `(#:phases
        (modify-phases %standard-phases
          (add-before 'install 'add-govuk-admin-template-initialiser
            ,govuk-admin-template-initialiser)
          (add-after
           'install 'alter-secrets.yml
           (lambda* (#:key outputs #:allow-other-keys)
             (substitute* (string-append
                           (assoc-ref outputs "out")
                           "/config/secrets.yml")
               (("SECRET_TOKEN")
                "SECRET_KEY_BASE")))))))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/specialist-publisher"))
   #:extra-inputs (list libffi)))

(define-public smokey
  (package-with-bundler
   (bundle-package
    (hash (base32 "19rzqm6731swpgyz0477vbk7kxysmjgaa8nh26jmwvps7701jl12")))
   (package
     (name "smokey")
     (version "0")
     (source
      (github-archive
       #:repository name
       #:commit-ish "61cd5a70ca48eb9a6e5ca2522d608db75dbb6582"
       #:hash (base32 "1n1ah83nps1bkqgpq8rd1v6c988w9mvkacrphwg7zz1d6k8fqska")))
     (build-system gnu-build-system)
     (inputs
      `(("ruby" ,ruby)
        ("chromium" ,ungoogled-chromium)))
     (arguments
      `(#:phases
        (modify-phases %standard-phases
          (replace 'configure (lambda args #t))
          (replace 'build (lambda args #t))
          (replace 'check (lambda args #t))
          (replace 'install
                   (lambda* (#:key inputs outputs #:allow-other-keys)
                     (let* ((out (assoc-ref outputs "out")))
                       (copy-recursively
                        "."
                        out
                        #:log (%make-void-port "w")))))
          (add-after 'patch-bin-files 'wrap-with-relative-path
                     (lambda* (#:key outputs #:allow-other-keys)
                       (let* ((out (assoc-ref outputs "out")))
                         (substitute* (find-files
                                       (string-append out "/bin"))
                           (((string-append out "/bin"))
                            "${BASH_SOURCE%/*}"))))))))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/smokey/"))
   #:extra-inputs (list
                   ;; For nokogiri
                   pkg-config
                   libxml2
                   libxslt)))

(define-public static
  (package-with-bundler
   (bundle-package
    (hash (base32 "11f28avm88l93p2hg8da87vjsf71bmafs20ff3y48ay0xwizha33")))
   (package
     (name "static")
     (version "release_3121")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "00w09cwcs2ijgcgg5wwygv1zgs13mwmsk1pcngwqqnf51si9ya3a")))
     (build-system rails-build-system)
     (arguments
      '(;; jasmine-rails seems to get annoyed if it's configuration
        ;; doesn't exist in the spec directory
        #:exclude-files ("tmp")
        #:phases
        (modify-phases %standard-phases
          (add-after 'install 'remove-redundant-page-caching
            (lambda* (#:key outputs #:allow-other-keys)
              ;; TODO: This caching causes problems, as the public
              ;; directory is not writable, and it also looks
              ;; redundant, as I can't see how the files are being
              ;; served from this directory.
              (substitute*
                  (string-append
                   (assoc-ref outputs "out")
                   "/app/controllers/root_controller.rb")
                (("  caches_page.*$")
                 "")))))))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/static"))
   #:extra-inputs (list
                   libffi)))

(define-public support
  (package-with-bundler
   (bundle-package
    (hash (base32 "0fbc4rny6qr57x5r64q2rdqp4iv8sg8qhs803600w9wc57ll8k5j")))
   (package
     (name "support")
     (version "release_832")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1l0a1gxh37agigqjxg5x4fl59cw56spw8kr1j0b3ga8dwagd9cj7")))
     (build-system rails-build-system)
     (arguments
      `(#:phases
        (modify-phases %standard-phases
          (add-after 'unpack 'patch-gds_sso-initializer
            (lambda _
              ;; TODO: Disable the creation of the development user,
              ;; as this breaks asset precompilation
              (substitute* "config/initializers/gds-sso.rb"
                (("if Rails.env == \"development\"")
                 "if Rails.env.development? and false"))
              #t))
          (add-before 'install 'add-govuk-admin-template-initialiser
            ,govuk-admin-template-initialiser))))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/support"))
   #:extra-inputs (list libffi)))

(define-public support-api
  (package-with-bundler
   (bundle-package
    (hash (base32 "1crlhn7k4lq5yw7l4hll9xcz46fqdzana50fi5fzip8ahrlcmrbj")))
   (package
     (name "support-api")
     (version "release_285")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0wdi4rw8psz2njfmv7g28qcsp46vh2v18w2km4mz391pa3ybyrx0")))
     (build-system rails-build-system)
     (inputs
      `(;; hostname is needed by the redis-lock gem
        ("inetutils" ,inetutils)
        ;; Loading the database structure uses psql
        ("postgresql" ,postgresql)))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/support-api"))
   #:extra-inputs (list postgresql libffi)))

(define-public transition
  (package-with-bundler
   (bundle-package
    (hash (base32 "18xgysbjrysp6ffmmrxrcamw9syyip6b8bkz4q9q1qhyh12169rs")))
   (package
     (name "transition")
     (version "release_922")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1brl2jlvnvjz7gsgc563zcd4p08hl1la51f9lffqkk1fhb8jdy1n")))
     (build-system rails-build-system)
     (arguments
      `(#:phases
        (modify-phases %standard-phases
          (add-before 'install 'add-govuk-admin-template-initialiser
            ,govuk-admin-template-initialiser))))
     (inputs
      `(;; hostname is needed by the redis-lock gem
        ("inetutils" ,inetutils)))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/transition"))
   #:extra-inputs (list libffi
                        postgresql)))

(define-public travel-advice-publisher
  (package-with-bundler
   (bundle-package
    (hash (base32 "1cg2zfzxnyjjxpdj6xzd5aswmh032ml1szx4vrgn8fgvlxgv5n7l")))
   (package
     (name "travel-advice-publisher")
     (version "release_581")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1cwp8vy7xxvw86mg1a87j0r7y0f30mkz77mgrr4p6vy5n1qb3j9k")))
     (build-system rails-build-system)
     (arguments
      `(#:phases
        (modify-phases %standard-phases
          (add-before 'install 'add-govuk-admin-template-initialiser
            ,govuk-admin-template-initialiser)
          (add-after 'install 'replace-mongoid.yml
            ,(replace-mongoid.yml)))))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/travel-advice-publisher"))
   #:extra-inputs (list libffi)))

(define-public whitehall
  (package-with-bundler
   (bundle-package
    (hash (base32 "17k80lj1k3asz4jflyqfzzjilk5bkklhqkfmwll4dc79jhczy379")))
   (package
     (name "whitehall")
     (version "release_14046")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1mij6rdnjvwa6p4mhz495c5w31yqcgrvx3n8266z3p2nf5hdiv98")))
     (build-system rails-build-system)
     (inputs
      `(("node" ,node)
        ;; TODO Adding curl here is unusual as ideally the gem
        ;; requiring it would link against the exact location of the
        ;; library at compile time.
        ("curl" ,curl)
        ;; hostname is needed by the redis-lock gem
        ("inetutils" ,inetutils)))
     (arguments
      `(#:phases
        (modify-phases %standard-phases
          (add-before 'precompile-rails-assets 'shared-mustache-compile
            (lambda _
              (chmod "app/assets/javascripts/templates.js" #o666)
              (invoke "bundle" "exec" "rake" "shared_mustache:compile")))
          (delete 'reset-gzip-timestamps)
          (add-before 'install 'add-govuk-admin-template-initialiser
            ,govuk-admin-template-initialiser)
          (add-after 'install 'replace-database.yml
                     ,(use-blank-database.yml))
          (add-after 'install 'create-data-directories
            (lambda* (#:key outputs #:allow-other-keys)
              (let ((out (assoc-ref outputs "out")))
                (for-each (lambda (name)
                            (mkdir-p (string-append out "/" name)))
                          '("incoming-uploads"
                            "clean-uploads"
                            "infected-uploads"
                            "asset-manager-tmp"
                            "carrierwave-tmp"
                            "attachment-cache"
                            "bulk-upload-zip-file-tmp")))
              #t)))))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/whitehall"))
   #:extra-inputs (list mariadb
                        libffi
                        openssl
                        curl
                        imagemagick)))
