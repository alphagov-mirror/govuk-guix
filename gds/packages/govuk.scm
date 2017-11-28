(define-module (gds packages govuk)
  #:use-module (ice-9 regex)
  #:use-module (ice-9 match)
  #:use-module (srfi srfi-1)
  #:use-module (guix packages)
  #:use-module (guix utils)
  #:use-module (guix build-system gnu)
  #:use-module (guix build-system trivial)
  #:use-module (guix build-system ruby)
  #:use-module (guix download)
  #:use-module (guix search-paths)
  #:use-module (guix records)
  #:use-module (guix git-download)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages admin)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages curl)
  #:use-module (gnu packages ruby)
  #:use-module (gnu packages certs)
  #:use-module (gnu packages commencement)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages databases)
  #:use-module (gnu packages xml)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages base)
  #:use-module (gnu packages tls)
  #:use-module (gnu packages node)
  #:use-module (gnu packages imagemagick)
  #:use-module (gnu packages golang)
  #:use-module (gnu packages web)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages libffi)
  #:use-module (gnu packages version-control)
  #:use-module (gnu packages rsync)
  #:use-module (gds build-system rails)
  #:use-module (gds packages utils)
  #:use-module (gds packages utils bundler)
  #:use-module (gds packages third-party phantomjs))

;; TODO: The native search paths in the ruby-2.3 package from GNU Guix
;; are wrong in the version currently in use, so fix this here.
(define ruby-2.3
  (package
    (inherit (@ (gnu packages ruby) ruby-2.3))
    (native-search-paths
     (list (search-path-specification
            (variable "GEM_PATH")
            (files (list "lib/ruby/gems/2.3.0")))))))

(define-public asset-manager
  (package-with-bundler
   (bundle-package
    (hash (base32 "0hpy6kszrg7n70ycnrv48lanqc8ga7y1pyh29z2hlk9kgbgxr1rj")))
   (package
     (name "asset-manager")
     (version "release_182")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0ha37vw7s33qw0byrc39701kclg5hz99jz3i0mbczqgcj07q5hk6")))
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
          (add-after 'install 'create-uploads-directory
                     (lambda* (#:key outputs #:allow-other-keys)
                       (let ((out (assoc-ref outputs "out")))
                         (mkdir-p (string-append out "/uploads"))))))
        #:ruby ,ruby-2.3))
     (synopsis "Manages uploaded assets (e.g. PDFs, images, ...)")
     (description "The Asset Manager is used to manage assets for the GOV.UK Publishing Platform")
     (license license:expat)
     (home-page "https://github.com/alphagov/asset-manager"))))

(define-public authenticating-proxy
  (package-with-bundler
   (bundle-package
    (hash (base32 "0fmrm4alqs2yl8wfry0pawahibxkk6l4frvkhgdfszwjffy9svy1")))
   (package
     (name "authenticating-proxy")
     (version "release_41")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0dhvipzya2gylm0lwqn9jicwf3n9z67bj0za6pi39c111h9jq8fz")))
     (build-system rails-build-system)
     (arguments
      `(#:phases
        (modify-phases %standard-phases
          (add-after 'install 'replace-mongoid.yml
            ,(replace-mongoid.yml)))
        #:ruby ,ruby-2.3))
     (synopsis "Proxy to add authentication via Signon")
     (description "The Authenticating Proxy is a Rack based proxy,
written in Ruby that performs authentication using gds-sso, and then
proxies requests to some upstream")
     (license #f)
     (home-page "https://github.com/alphagov/authenticating-proxy"))))

(define-public bouncer
  (package-with-bundler
   (bundle-package
    (hash (base32 "0gr9xds4rjy97mv9llc974jpsnr2wc0h3znaqaf6v3132gg67c72")))
   (package
     (name "bouncer")
     (version "release_209")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0iwp4y2dh894x4zdfwlq7w7d6j7wn3lfzm5gwwjh8rf8i624mmnp")))
     (build-system rails-build-system)
     (synopsis "Rack based redirector backed by the Transition service")
     (description "")
     (license license:expat)
     (home-page "https://github.com/alphagov/bouncer"))
   #:extra-inputs (list libffi postgresql)))

(define-public calculators
  (package-with-bundler
   (bundle-package
    (hash (base32 "1l08pn17nxdd0h1mzmchfh1zcy8k5px9gc25w9sik7828x6sk9vf")))
   (package
     (name "calculators")
     (version "release_208")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1lxg9njd5m66dghc9r7ivnbzf9wzdb3bi5xb2djz84qzv7zsg0v4")))
     (build-system rails-build-system)
     (synopsis "Calculators provides the Child benefit tax calculator")
     (description "")
     (license license:expat)
     (home-page "https://github.com/alphagov/calculators"))
   #:extra-inputs (list libffi)))


(define-public calendars
  (package-with-bundler
   (bundle-package
    (hash (base32 "1wm9px6zsbqchq6kz8fdp3m6wq0mnnlimyijbghh7k3bp7ph8p47")))
   (package
     (name "calendars")
     (version "release_432")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "08w5inb9j2fczikwwwpvbdq3jsyn6i6amrfh9hh4m870p6dki0wz")))
     (build-system rails-build-system)
     (synopsis "Serves calendars on GOV.UK")
     (description "")
     (license license:expat)
     (home-page "https://github.com/alphagov/calendars"))))

(define-public collections
  (package-with-bundler
   (bundle-package
    (hash (base32 "036sldgls8z0fh7z3z9wyz7hi4m1w608vak5d62wxp0h8i9y5410")))
   (package
     (name "collections")
     (version "release_392")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1hylh2h2mn51wh36cjhjs370pj42n1nl2mshj7fvlhhxpjvh3nnh")))
     (build-system rails-build-system)
     (synopsis "Collections serves the new GOV.UK navigation and other pages")
     (description "")
     (license license:expat)
     (home-page "https://github.com/alphagov/collections"))))

(define-public collections-publisher
  (package-with-bundler
   (bundle-package
    (hash (base32 "1rl3s71wrc81dmp8gay73r9abnx3aqv8mma4m7j81xm2q0n9m0kp")))
   (package
     (name "collections-publisher")
     (version "release_268")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1iff8p126jrc2qh9i490asslmmd25c9q1xmsvh205rfcjgnwrsxi")))
     (build-system rails-build-system)
     (arguments
      `(#:phases
        (modify-phases %standard-phases
          (add-after 'install 'replace-database.yml
                     ,(use-blank-database.yml)))))
     (synopsis "Used to create browse and topic pages")
     (description "")
     (license license:expat)
     (home-page "https://github.com/alphagov/collections-publisher"))
   #:extra-inputs (list mariadb)))

(define-public contacts-admin
  (package-with-bundler
   (bundle-package
    (hash (base32 "1dy5pv4k83qfjbhiq997hpfqsks8mh9iv6nww289mxxd185cwzqg")))
   (package
     (name "contacts-admin")
     (version "release_358")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1ryvx4gx2js1wdxkls2l2wy70fiwqv67m8sq970zg93ailxikjzd")))
     (build-system rails-build-system)
     (inputs
      `(;; hostname is needed by the redis-lock gem
        ("inetutils" ,inetutils)))
     (arguments `(#:precompile-rails-assets? #f))
     (synopsis "Used to publish organisation contact information to GOV.UK")
     (description "")
     (license license:expat)
     (home-page "https://github.com/alphagov/contacts-admin"))
   #:extra-inputs (list mariadb)))

(define-public content-performance-manager
  (package-with-bundler
   (bundle-package
    (hash (base32 "0vd34rq3vciwvkdml7z1wnn3mm3g6mqbrgszl8211x8qvc9f4cdf")))
   (package
     (name "content-performance-manager")
     (version "release_313")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "03l5dmsb9sqc69xlys7558z3m0bdwhmc32mcrpcd40wb3g7b61c5")))
     (build-system rails-build-system)
     (arguments
      `(#:phases
        (modify-phases %standard-phases
          (add-after 'install 'replace-database.yml
                     ,(use-blank-database.yml)))))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/content-performance-manager"))
   #:extra-inputs (list postgresql libffi)))

(define-public content-store
  (package-with-bundler
   (bundle-package
    (hash (base32 "02lrv2afqwhnv9aqkzy7aqc7dq9xgr9giypi7fzr10gr0hb8kjzr")))
   (package
     (name "content-store")
     (version "release_670")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "17jwxxppk1nf0wpj1km0dzflfzsnr3vii1qk8hx9m1g47fgj6w87")))
     (build-system rails-build-system)
     (arguments `(#:precompile-rails-assets? #f))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/content-store"))))

(define-public content-tagger
  (package-with-bundler
   (bundle-package
    (hash (base32 "1lyy71b1yrxymr36ls145kxfxn4jwxzjxjrf63qvvvmn8vbqbb5d")))
   (package
     (name "content-tagger")
     (version "release_584")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1clbfnmsj8srkiwzmz4sb0lyqm6201rjxvfw4xahhp6fk62m27pm")))
     (build-system rails-build-system)
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/content-tagger"))
   #:extra-inputs (list postgresql)))

(define-public design-principles
  (package-with-bundler
   (bundle-package
    (hash (base32 "01gg6yy8wa1g1zmf4072xa7v1lvyhdqhhpi8w29krl27anfag3qa")))
   (package
     (name "design-principles")
     (version "release_876")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1brak8fq2406i666iqq1drm1lamcvfdjrw8lh25gp6y60d96nnif")))
     (build-system rails-build-system)
     (arguments `(;; Asset precompilation fails
                  #:precompile-rails-assets? #f
                  #:ruby ,ruby-2.3))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/design-principles"))))

(define-public email-alert-api
  (package-with-bundler
   (bundle-package
    (hash (base32 "0kvrhw9hn3i9351jq2d582fnvghfavh3b703bma6g6ffz55l1ddp")))
   (package
     (name "email-alert-api")
     (version "release_269")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "08ms0nfk84xp150bqa0gavw6a9y30gz3hncc1cnww32i49wyvc34")))
     (build-system rails-build-system)
     (arguments
      `(#:precompile-rails-assets? #f
        #:phases
        (modify-phases %standard-phases
          (add-after 'install 'replace-redis.yml
                     ,(replace-redis.yml))
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
    (hash (base32 "07s40vqrqbhapihsa02wg36phhrd1dc3fj49jx0jyyn76h3fpdfp")))
   (package
     (name "email-alert-frontend")
     (version "release_53")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "172caq53msskkv5z93khmc28ldkn9z2293cayhw0n035kl6d4sa9")))
     (build-system rails-build-system)
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/email-alert-frontend"))
   #:extra-inputs (list libffi)))

(define-public email-alert-service
  (package-with-bundler
   (bundle-package
    (hash (base32 "1nxvkdzgd46986qcyvfgnhn8gbhhwda27rx37c14x0ylwka91230")))
   (package
     (name "email-alert-service")
     (version "release_91")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0d52gk5mnyb0bxbnf78skis7jgi9l5r2cnda4yam01q2i89xmxjj")))
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
     (home-page "https://github.com/alphagov/email-alert-service/"))))

(define-public feedback
  (package-with-bundler
   (bundle-package
    (hash (base32 "0fmlbhh10s47xps57819h1fq5fr1yd9ypi70gfp22z151nfd4llk")))
   (package
     (name "feedback")
     (version "release_334")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1ysplj9rca9d18g2wkjjahy3hjy534c8yxqj414wz3p221jg5xh8")))
     (build-system rails-build-system)
     (arguments `(#:ruby ,ruby-2.3))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/feedback"))))

(define-public finder-frontend
  (package-with-bundler
   (bundle-package
    (hash (base32 "021gabbjnj8jk0fh2dr8kx06g91n4q0hl2c5rdi5pj5yvf7lq6cw")))
   (package
     (name "finder-frontend")
     (version "release_331")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "00r6w0z5wv1nz0g2rbhdc2hdmy01vrng952l67yjh0plh16vq4xr")))
     (build-system rails-build-system)
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/finder-frontend"))))

(define-public frontend
  (package-with-bundler
   (bundle-package
    (hash (base32 "0sxwj68kqi2gr229d4hnqciqzm85qi8rxx6pj8588cp1w7cfaq7q")))
   (package
     (name "frontend")
     (version "release_2769")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0dq97pklf0fvkpzfxcarpj7d6gljp8qzljsd4m0lawrwn58vzang")))
     (build-system rails-build-system)
     (arguments `(#:ruby ,ruby-2.3))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/frontend"))))

(define-public government-frontend
  (package-with-bundler
   (bundle-package
    (hash (base32 "0fzza5g62nj5w6paiam26x5dhd78br58vjpnm9901gkmirkpmdxi")))
   (package
     (name "government-frontend")
     (version "release_504")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "009sg085gzqm3i9bx63mv2b3b2zij779wy7yikpay5khwbs7q93y")))
     (build-system rails-build-system)
     (arguments
      `(#:phases
        (modify-phases %standard-phases
          (add-before 'bundle-install 'replace-ruby-version
                      ,(replace-ruby-version (package-version ruby))))))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/government-frontend"))))

(define-public govuk-content-schemas
  (package
    (name "govuk-content-schemas")
    (version "release_645")
    (source
     (github-archive
      #:repository name
      #:commit-ish version
      #:hash (base32 "0jr468qp7ny6271rl9fxgdicv2m6pz0v48vf2g67mfsyanv09v4x")))
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

(define-public hmrc-manuals-api
  (package-with-bundler
   (bundle-package
    (hash (base32 "1ijl8x8wbhgb57xl7mrbpd5hcwdnm1rdr6pdi5ymz810fm3sk5ih")))
   (package
     (name "hmrc-manuals-api")
     (version "release_196")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0qidf3y18b841fgvxdnd778qyakiabaagw5n84yri67hyia70p5v")))
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
    (hash (base32 "0cnsn0f5lfmdzcw5bbpnhdnrnyfay8q44d0g0yda12wdxmdaa0xs")))
   (package
     (name "imminence")
     (version "release_321")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1rpajn4s7lhvxa483c3widn0gfbddsif53cscg3kq7ygsqzdg7gd")))
     (build-system rails-build-system)
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/imminence"))))

(define-public info-frontend
  (package-with-bundler
   (bundle-package
    (hash (base32 "17yzyzddcqgz9z0vf3h7m97qivf2fsszz4xpziqi6j6wj8nz63yq")))
   (package
     (name "info-frontend")
     (version "release_85")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0ix4ri739sigj7ycm8ylsdp320cnllr1qvawkdkb8bqc27azvyxk")))
     (build-system rails-build-system)
     (arguments `(#:precompile-rails-assets? #f))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/info-frontend"))))

(define-public licence-finder
  (package-with-bundler
   (bundle-package
    (hash (base32 "06rhgch7mhia739fhjpf6plbqwpaiy23k88sjxwlmsvp7gvswirv")))
   (package
     (name "licence-finder")
     (version "release_298")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1xrp8m6mkq2y60d6jggp16fcpplil1hf0y7hrjbpsfh6qfclgaxs")))
     (build-system rails-build-system)
     (arguments `(#:ruby ,ruby-2.3))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/licence-finder"))))

(define-public local-links-manager
  (package-with-bundler
   (bundle-package
    (hash (base32 "0wf6f7xv1apdbxlzsln4xqrp5j4g48x4ga87zv479g5i3cq32w13")))
   (package
     (name "local-links-manager")
     (version "release_135")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0l34wirf9x9fkcwg419kk4lzrx8zi09p9imbscr66r03xmvsgz4d")))
     (build-system rails-build-system)
     (inputs
      `(;; hostname is needed by the redis-lock gem
        ("inetutils" ,inetutils)))
     (arguments
      `(#:precompile-rails-assets? #f ;; Asset precompilation fails
        #:phases
        (modify-phases %standard-phases
          (add-after 'install 'replace-database.yml
            ,(use-blank-database.yml)))
        #:ruby ,ruby-2.3))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/local-links-manager"))
   #:extra-inputs (list postgresql)))

(define-public manuals-frontend
  (package-with-bundler
   (bundle-package
    (hash (base32 "1y78gy9kd26ijdsff7wpiwcvp85zjvkvzpa63ci5barbf8dbkr4w")))
   (package
     (name "manuals-frontend")
     (version "release_218")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0b8j62yi9mxph4q7kb8abw6ddzzvmq7q4qw68v9y0h3mb183p8ny")))
     (build-system rails-build-system)
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/manuals-frontend"))))

(define-public manuals-publisher
  (package-with-bundler
   (bundle-package
    (hash (base32 "05zw9dmmhq0kc4rp4kax0i70wh3fia9chxwkrjgfb7s3s9r4hka3")))
   (package
     (name "manuals-publisher")
     (version "release_983")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1maf925rcb400zd4i4nmlskjxn8ky90504lp6zkf8kkx09abwm0a")))
     (build-system rails-build-system)
     (arguments
      `(#:precompile-rails-assets? #f ;; Asset precompilation fails
        #:phases
        (modify-phases %standard-phases
          (add-after 'install 'replace-mongoid.yml
                     ,(replace-mongoid.yml #:mongoid-version "3")))))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/manuals-publisher"))))

(define-public maslow
  (package-with-bundler
   (bundle-package
    (hash (base32 "0l5kwbmg6d863yn6jl2b5gv5m74l5yabsf6wckja6qz92vycaqdw")))
   (package
     (name "maslow")
     (version "release_203")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0gx9b0xm8n7mkv5d0qs4hmd4xkdrzbjvkzizg78f937233kyyymq")))
     (build-system rails-build-system)
     (arguments
      `(#:phases
        (modify-phases %standard-phases
          (add-after 'install 'replace-mongoid.yml
                     ,(replace-mongoid.yml))
          (add-after 'replace-mongoid.yml 'replace-gds-sso-initializer
                     ,(replace-gds-sso-initializer)))))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/maslow"))
   #:extra-inputs (list libffi)))

(define-public policy-publisher
  (package-with-bundler
   (bundle-package
    (hash (base32 "0c0f9p83ksg7pixv64c58bachylvb5dfn0r0h9n94l8dlljv5v06")))
   (package
     (name "policy-publisher")
     (version "release_180")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "15nrys9i7g0rd9k8jqk2mwx02yy2vrpa0jcg5k046jvp1b5cbqpj")))
     (build-system rails-build-system)
     (arguments
      `(#:phases
        (modify-phases %standard-phases
          (add-after 'install 'replace-database.yml
                     ,(use-blank-database.yml)))))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/policy-publisher"))
   #:extra-inputs (list postgresql)))

(define-public publisher
  (package-with-bundler
   (bundle-package
    (hash (base32 "1906ggg936bapi2k9niqjsnlga3azh6ig6h42rgpm644gw3b7zaf")))
   (package
     (name "publisher")
     (version "release_1826")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "16f0rivjg0i2675qwpns4vsvyq5rkzlk04kl4ajbhia7szp6w95f")))
     (build-system rails-build-system)
     (arguments
      `(#:phases
        (modify-phases %standard-phases
          (add-after 'install 'replace-mongoid.yml
                     ,(replace-mongoid.yml))
          (add-after 'replace-mongoid.yml 'replace-gds-sso-initializer
                     ,(replace-gds-sso-initializer)))))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/publisher"))))

(define-public publishing-api
  (package-with-bundler
   (bundle-package
    (hash (base32 "12hrqq0dwfj7dp1n96fsvb3r1wy9amphfqwidmdmh6ary1qsa9m0")))
   (package
     (name "publishing-api")
     (version "release_1032")
     (source
      (github-archive
       #:repository "publishing-api"
       #:commit-ish version
       #:hash (base32 "1c2x0wfibb343jq9f42jchv451hmvrvh7khbp74ac36hy9nhwdci")))
     (build-system rails-build-system)
     (arguments `(#:precompile-rails-assets? #f
                  #:ruby ,ruby-2.3))
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
                   ;; Required by the pg gem
                   postgresql)))

(define-public publishing-e2e-tests
  (package-with-bundler
   (bundle-package
    (hash
     (base32 "0nficwk1id99zlg57ahkbz5lrjalx45vf8ywqi54kazlfjp4x50b")))
   (package
     (name "publishing-e2e-tests")
     (version "0")
     (source
      (github-archive
       #:repository "publishing-e2e-tests"
       #:commit-ish "5451c1f1b7baa0ac4849deed278c98739cdf0f01"
       #:hash (base32 "116l3fhmr4jqpyf95gzpwmbqxcrhdj63f7npd1n8vfv521smig7r")))
     (build-system gnu-build-system)
     (inputs
      `(("ruby" ,ruby)
        ("phantomjs" ,phantomjs)))
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
                        #:log (%make-void-port "w"))))))))
     (synopsis "Suite of end-to-end tests for GOV.UK")
     (description "")
     (license license:expat)
     (home-page "https://github.com/alphagov/publishing-e2e-tests"))
   #:extra-inputs (list
                   ;; For nokogiri
                   pkg-config
                   libxml2
                   libxslt)))

(define-public release
  (package-with-bundler
   (bundle-package
    (hash (base32 "0m53a3zcgmdy4sfbgix4i8fdq0rqqj680gk51qr02w41a8wlvw96")))
   (package
     (name "release")
     (version "release_261")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0p5skmgd5lgffgqgkfz5liqc6cfkw9hnf7fpd5a38sxzvj7fpq3r")))
     (build-system rails-build-system)
     (arguments
      `(#:phases
        (modify-phases %standard-phases
          (add-after 'install 'replace-database.yml
                     ,(use-blank-database.yml)))))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/release"))
   #:extra-inputs (list mariadb)))

(define-public router
  (package
    (name "router")
    (version "release_178")
    (source
     (github-archive
      #:repository name
      #:commit-ish version
      #:hash (base32 "09dcm151dq5vjsglw2hih9hanh85rdkx5q4bi089jiwx65fkx71z")))
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
    (hash (base32 "0hm9gkhynr548bj4xhzx8bdaaxd8h8z61flmg05ar24ja4wgjlzv")))
   (package
     (name "router-api")
     (version "release_126")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1zg6b6xf5rxj1z7n9az0hm8698kcv7kgpdy5gpnllpxbr25f5x0j")))
     (build-system rails-build-system)
     (arguments `(#:precompile-rails-assets? #f
                  #:ruby ,ruby-2.3))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/router-api"))))

(define-public rummager
  (package-with-bundler
   (bundle-package
    (hash (base32 "17vbhscv37v85nv4dkv3gmcdw4n4bhfml8hr17cfr93mk0rlisk2")))
   (package
     (name "rummager")
     (version "release_1570")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0g2qp7ih2hrkwd19209935b1fdhjsrldvry5avnzda3ms0szfd15")))
     (build-system rails-build-system)
     (arguments
      `(#:precompile-rails-assets? #f
        #:phases
        (modify-phases %standard-phases
          (add-after
           'install 'replace-redis.yml
           ,(replace-redis.yml)))
        #:ruby ,ruby-2.3))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/rummager"))
   #:extra-inputs (list libffi)))

(define-public search-admin
  (package-with-bundler
   (bundle-package
    (hash (base32 "1b08nkhlcc9b7p440bghfzrpx4cb8z7f0w1df58jj51xfp4pin60")))
   (package
     (name "search-admin")
     (version "release_99")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1vrv8zk25v6rp595havjglylqjkppqmg9pp05pw386cxm1nnrwcj")))
     (build-system rails-build-system)
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/search-admin"))
   #:extra-inputs (list mariadb)))

(define-public service-manual-frontend
  (package-with-bundler
   (bundle-package
    (hash (base32 "0mpnc37gl0x0l9wkpbp3j71y4dnsy0rz9x9cgav7p908hyw0jlzc")))
   (package
     (name "service-manual-frontend")
     (version "release_106")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1y41qjikhaqj8c7gwfbcr4hzfqyz3sjh57i8b96r0ixhsliqgb6h")))
     (build-system rails-build-system)
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/service-manual-frontend"))))

(define-public service-manual-publisher
  (package-with-bundler
   (bundle-package
    (hash (base32 "0hq9bvfvhm15paq43b3vxviqi18dfn29diybg8v696sjd5bv8cr4")))
   (package
     (name "service-manual-publisher")
     (version "release_307")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1g7f9yzh05pfrm7vj7sf36vk0i3jsmz7df74cjhjbm7cq886qwkf")))
     (build-system rails-build-system)
     (inputs
      `(;; Loading the database structure uses psql
        ("postgresql" ,postgresql)))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/service-manual-publisher"))
   #:extra-inputs (list postgresql)))

(define-public short-url-manager
  (package-with-bundler
   (bundle-package
    (hash (base32 "1vbyk8kj51f98a2y77nfb5sgnc8w4pw5cv966l9kzbk7xnlh2pzp")))
   (package
     (name "short-url-manager")
     (version "release_130")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1gmi5r557wrb2k9d4xaysbb5ia06dgnfl1fpk29ajanz92hr65h1")))
     (build-system rails-build-system)
     (arguments `(#:precompile-rails-assets? #f ;; Asset precompilation fails
                  #:ruby ,ruby-2.3))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/short-url-manager"))))

(define-public signon
  (package-with-bundler
   (bundle-package
    (hash (base32 "1y0xqla6i058q4x3sx667gxrjwp2380jpamdng7x5jsdc7a31nhd"))
    (without '("development" "test")))
   (package
     (name "signon")
     (version "release_947")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1jsqba4qbkrv2vgpj6cjzw41qf44x1m59ykmn4019fcgpysh6rsj")))
     (build-system rails-build-system)
     (arguments
      `(#:phases
        (modify-phases %standard-phases
          (add-after 'install 'replace-database.yml
                     ,(use-blank-database.yml)))
        #:ruby ,ruby-2.3))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/signon"))
   #:extra-inputs (list mariadb
                        postgresql
                        openssl)))

(define-public smart-answers
  (package-with-bundler
   (bundle-package
    (hash (base32 "13anm7755dvxql8v92yiripw3f13cagmn92345k45lnh1ja428nb")))
   (package
     (name "smart-answers")
     (version "release_3790")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "05mjkq27h5r9arm1fgwqslamx79iwkfdz94qgcy7p2rkhq8dldkl")))
     (build-system rails-build-system)
     (arguments `(#:precompile-rails-assets? #f)) ;; Asset precompilation fails
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/smart-answers"))))

(define-public specialist-publisher
  (package-with-bundler
   (bundle-package
    (hash (base32 "1b94hfm41r7zl1mp2ag9n4vgvp1gsxf7zbcw5z0hb2bh21njbvll"))
    (without '("development" "test")))
   (package
     (name "specialist-publisher")
     (version "release_841")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0jmf53kgl66ldhgbpzl6bqg4k1kdx9a468nnmy62286s22dx5s5b")))
     (build-system rails-build-system)
     (arguments
      `(#:phases
        (modify-phases %standard-phases
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
     (home-page "https://github.com/alphagov/specialist-publisher"))))

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
        ("phantomjs" ,phantomjs)))
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
    (hash (base32 "1lqjrdf223g9k09q7csqgrqk1idm9dqg2r8yasl9lm18ja92vzv7")))
   (package
     (name "static")
     (version "release_2723")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "03k62r54hc048f00fjyha01vh2v1bni5r5plhh1acfqlzl9rkkg7")))
     (build-system rails-build-system)
     (arguments `(#:precompile-rails-assets? #f
                  #:ruby ,ruby-2.3))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/static"))))

(define-public support
  (package-with-bundler
   (bundle-package
    (hash (base32 "0zi4hwmwjz5625s5z7mqrfp59xis5drncpjc4lic32dbxqa6wwab")))
   (package
     (name "support")
     (version "release_602")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "13cy987gn45fc4vfniyai43gw931xd79minxcnr7zfd7bqqwagh6")))
     (build-system rails-build-system)
     (arguments
      `(#:precompile-rails-assets? #f ;; Asset precompilation fails
        #:phases
        (modify-phases %standard-phases
          (add-after
           'install 'replace-redis.yml
           ,(replace-redis.yml)))))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/support"))
   #:extra-inputs (list libffi)))

(define-public support-api
  (package-with-bundler
   (bundle-package
    (hash (base32 "09d84qlgvbw8yvhz9fkr6k6gjn9zlcl23j1jaq8dhq21hw8nh0kg")))
   (package
     (name "support-api")
     (version "release_134")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0q23c6wkjf6nlif3lrnrs3n5qfc9pchd6cbp7xm2pm7apgawskaw")))
     (build-system rails-build-system)
     (arguments `(#:ruby ,ruby-2.3))
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
    (hash (base32 "15djzy3kh7vs3xsb15ia00a4kvqi7r6shb7sj0zb283n0fxnsamp")))
   (package
     (name "transition")
     (version "release_796")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0rh78566rbf05c6gxbqfsgjg6x661xb4yniq9hd0kvnfzyf2jg3i")))
     (build-system rails-build-system)
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/transition"))
   #:extra-inputs (list postgresql)))

(define-public travel-advice-publisher
  (package-with-bundler
   (bundle-package
    (hash (base32 "10yn7b9d82y7y8rglhga8g4pd1r93i71kf402gmsjpq5y8gkwbs2")))
   (package
     (name "travel-advice-publisher")
     (version "release_278")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1clch9rvmv42jkw4997m6nywr3a0h6f5z3r39d23fgykhwxxf46k")))
     (build-system rails-build-system)
     (arguments
      `(#:phases
        (modify-phases %standard-phases
          (add-after 'install 'replace-mongoid.yml
            ,(replace-mongoid.yml)))
        #:ruby ,ruby-2.3)) ;; There might be issues with Mongoid 2 and ruby 2.4
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/travel-advice-publisher"))
   #:extra-inputs (list libffi)))

(define-public whitehall
  (package-with-bundler
   (bundle-package
    (hash (base32 "0zx79r2vplz06nh7xdxqvxdrv9m9jjs6rn05wlayc3lrzaln41dn")))
   (package
     (name "whitehall")
     (version "release_13107")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1hjg2qsqa4xnahc5z9j5qlmybcy9mmiim0mcy0qvf8pbk6b34rls")))
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
          (add-after 'install 'replace-database.yml
                     ,(use-blank-database.yml))
          (add-after 'install 'set-bulk-upload-zip-file-tmp
                     (lambda* (#:key outputs #:allow-other-keys)
                       (substitute* (string-append
                                     (assoc-ref outputs "out")
                                     "/config/initializers/bulk_upload_zip_file.rb")
                         (("Rails\\.root\\.join\\('bulk-upload-zip-file-tmp'\\)")
                          "\"/tmp/whitehall/bulk-upload-zip-file\"")))))))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/whitehall"))
   #:extra-inputs (list mariadb
                        libffi
                        curl
                        imagemagick)))
