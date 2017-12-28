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
    (hash (base32 "0q1wcn6vmqscjd4swfrrjklnz69fr1lz5aimzj96xq9m9x0bmymw")))
   (package
     (name "asset-manager")
     (version "release_210")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0hqswnnrr7fwajvpjhyzgc3f9w6aqkl13nhxw44s551l50bsxhfa")))
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
     (home-page "https://github.com/alphagov/asset-manager"))
   #:extra-inputs (list libffi)))

(define-public authenticating-proxy
  (package-with-bundler
   (bundle-package
    (hash (base32 "1v6qb3f8v11yn3fy2ghxaynwmsgas61wkj8f5cw7mif8r1d22w7z")))
   (package
     (name "authenticating-proxy")
     (version "release_46")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "16lq0m56l1mqvpgq8b4p55f7196hs59l6d2d7cnf33nkfagc24hy")))
     (build-system rails-build-system)
     (arguments
      `(#:precompile-rails-assets? #f
        #:phases
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
    (hash (base32 "1jgclkyfgicr3wjixi3vdg2n9bxl0fklxiwnsffhpb9bnkgf2nxm")))
   (package
     (name "bouncer")
     (version "release_219")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0lymfpwvv899p7pbi2ppd16wagws2x7bzangzhfaxm37khhdj4vr")))
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
    (hash (base32 "14pb6532apainqy7clrq4fmvh7ga2x12l7bb54kjkj820b8hvgcr")))
   (package
     (name "calculators")
     (version "release_222")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "108yfnzyxzcbqwmzijkkmg940kn7q18fn1zrbi9x1fggwv7wf1wi")))
     (build-system rails-build-system)
     (synopsis "Calculators provides the Child benefit tax calculator")
     (description "")
     (license license:expat)
     (home-page "https://github.com/alphagov/calculators"))
   #:extra-inputs (list libffi)))


(define-public calendars
  (package-with-bundler
   (bundle-package
    (hash (base32 "0yxq74jganan04ivqqkmis3s7d5dbq7qh97s793w3kh5rbflc6n7")))
   (package
     (name "calendars")
     (version "release_444")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0lxh30fiihb3p789kym9716ydhdvfxcdv6hd5nwcj7dqknyiqcbd")))
     (build-system rails-build-system)
     (synopsis "Serves calendars on GOV.UK")
     (description "")
     (license license:expat)
     (home-page "https://github.com/alphagov/calendars"))
   #:extra-inputs (list libffi)))

(define-public collections
  (package-with-bundler
   (bundle-package
    (hash (base32 "0klcav9cwc2ddiqmgj6ig9mifr5mq302ccf6ygycjci77214dwi6")))
   (package
     (name "collections")
     (version "release_417")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0dbsqzi2ncksdhsh21ra5k5plpr46f634g4rn0ry53415lr39i1s")))
     (build-system rails-build-system)
     (synopsis "Collections serves the new GOV.UK navigation and other pages")
     (description "")
     (license license:expat)
     (home-page "https://github.com/alphagov/collections"))
   #:extra-inputs (list libffi)))

(define-public collections-publisher
  (package-with-bundler
   (bundle-package
    (hash (base32 "06hhvjl3m3myd2idlfngrd438vb509lkawza06a6d2vs0kwdvmnq")))
   (package
     (name "collections-publisher")
     (version "release_289")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1i0r7wjq9kklj963bnabda6wib787v90ljzqjhpxknj6zynr8xwg")))
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
   #:extra-inputs (list mariadb
                        libffi)))

(define-public contacts-admin
  (package-with-bundler
   (bundle-package
    (hash (base32 "0qqm4nnvprj02vmi3lqyr2saqh8z8g4df7c9gwqdd4fykdn8c2ba")))
   (package
     (name "contacts-admin")
     (version "release_364")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "19jpf12ykb4xrdahzah4d23pnjh7awbwpv831nnmppwxgnyrm9cj")))
     (build-system rails-build-system)
     (inputs
      `(;; hostname is needed by the redis-lock gem
        ("inetutils" ,inetutils)))
     (arguments `(#:precompile-rails-assets? #f))
     (synopsis "Used to publish organisation contact information to GOV.UK")
     (description "")
     (license license:expat)
     (home-page "https://github.com/alphagov/contacts-admin"))
   #:extra-inputs (list libffi
                        mariadb)))

(define-public content-performance-manager
  (package-with-bundler
   (bundle-package
    (hash (base32 "1iz4lxfz79ykwzpii8bl6dw664hq1jxq60vdyqwv2asnl9cff25p")))
   (package
     (name "content-performance-manager")
     (version "release_350")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1l8h3qjlbfyvy821ghr2ir02j80if15kajk84xd1wzx1nkckpvj9")))
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
    (hash (base32 "0cyj767ky58mfbaz593jhhwc1n3p1nrysdw5r17zg603z3bpg2zb")))
   (package
     (name "content-store")
     (version "release_694")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1njmfqjmdyb0q5bn5ssfjdf0682gmfcf5qi6kbk3nww5k3vc715b")))
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
    (hash (base32 "004a3jhalmwj244nj6rk1x51h1jdlfkck5md4vxrn07w9qs83469")))
   (package
     (name "content-tagger")
     (version "release_639")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "10sssbxxn6dr7q40r2rrjf1fsv837hapimiipgsaczyj884zmcjq")))
     (build-system rails-build-system)
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/content-tagger"))
   #:extra-inputs (list postgresql
                        libffi)))

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
    (hash (base32 "0750ph6k24r8kg4l7la5q1b0f5zlpbiy2zdbsmvwf6g1cd6prrw6")))
   (package
     (name "email-alert-api")
     (version "release_352")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0966rhjyy1mm4prlymyxc64s4iqzqds15xlqsflphlcahfz0ssil")))
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
    (hash (base32 "03mrmahh5qcl6q6mq5mxmiajmgvhvclmw4lwlbp7sjjs50c5jzpc")))
   (package
     (name "email-alert-frontend")
     (version "release_75")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1sk224ld4cph4688b0psh4j7zw5x5lrvrd8q2mhzspl1x6x6dflc")))
     (build-system rails-build-system)
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/email-alert-frontend"))
   #:extra-inputs (list libffi)))

(define-public email-alert-service
  (package-with-bundler
   (bundle-package
    (hash (base32 "1pqvr09a1w8cp11s79k61zmvd7j87apd0yi5fyjrn0amlls1kzk8")))
   (package
     (name "email-alert-service")
     (version "release_99")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "066i4n2sypgbsqrchg8ckyr27ia1xbjnjy421izvxarvgnypf9i4")))
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
    (hash (base32 "12i5grvh04gwzi1b597m95ggz7bi7lilzpjs56ddjys6z9413bi8")))
   (package
     (name "feedback")
     (version "release_348")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "11gzaznm7hzradw9g5vj8jkj1gvxar6dyya8k18gxwql3bgf5zby")))
     (build-system rails-build-system)
     (arguments `(#:ruby ,ruby-2.3))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/feedback"))
   #:extra-inputs (list libffi)))

(define-public finder-frontend
  (package-with-bundler
   (bundle-package
    (hash (base32 "1n7cdgam5vblabr4p5bhyn8lcxpvw1xpj78j1la77x8hpby44n16")))
   (package
     (name "finder-frontend")
     (version "release_352")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0mk64imdqkzminbg8mfpk95n36qh2lq5gy3pkvhk8vhj9gnln1dz")))
     (build-system rails-build-system)
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/finder-frontend"))
   #:extra-inputs (list libffi)))

(define-public frontend
  (package-with-bundler
   (bundle-package
    (hash (base32 "196l2j6m4cn49asr9nvj0xlk80wrab78av29jyz44qkr9jy8igxr")))
   (package
     (name "frontend")
     (version "release_2792")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1b8z6h41kmzn60fgbhdmqd6p58wx1zdscgb3rc4d0z897s9pqb3s")))
     (build-system rails-build-system)
     (arguments `(#:ruby ,ruby-2.3))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/frontend"))))

(define-public government-frontend
  (package-with-bundler
   (bundle-package
    (hash (base32 "13zp87skcklhp4lhghgjnc5rjlinwnadgknf85z4d8a1bn2zg0wf")))
   (package
     (name "government-frontend")
     (version "release_562")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0ixszg9ndq4xn2rp0xxb5abb8i8x866b0j46v2xxp6zxnm41677r")))
     (build-system rails-build-system)
     (arguments
      `(#:phases
        (modify-phases %standard-phases
          (add-before 'bundle-install 'replace-ruby-version
                      ,(replace-ruby-version (package-version ruby))))))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/government-frontend"))
   #:extra-inputs (list libffi)))

(define-public govuk-content-schemas
  (package
    (name "govuk-content-schemas")
    (version "release_671")
    (source
     (github-archive
      #:repository name
      #:commit-ish version
      #:hash (base32 "07l027p0lihswqnz6wzwpga6pm49crdvxzn0q571dbpnwz73h24x")))
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
    (hash (base32 "1s62bw8414380smfb2yklgidl4ibmjc1aa0dbh7jiiyikpknd7cz")))
   (package
     (name "hmrc-manuals-api")
     (version "release_216")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0ysgs67mr10z1g3h5civx5qz8jzsf3j86xhmwvk7n21pl65gc0hj")))
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
    (hash (base32 "1vxlmwqhg30l4zkpd0rfnfl4scgx9w2ir00sgzrsh9p19czflyld")))
   (package
     (name "imminence")
     (version "release_322")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1hr93nfg3gnxm411l0v8skff9bkl77mqbb3xkmyf8gjlm4izmxc6")))
     (build-system rails-build-system)
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/imminence"))
   #:extra-inputs (list libffi)))

(define-public info-frontend
  (package-with-bundler
   (bundle-package
    (hash (base32 "0amsnbr5p2hpqqh4qw72avjb8khb9kqd6hzb03sn3l94dj89s18r")))
   (package
     (name "info-frontend")
     (version "release_89")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "149pz1c88p36v8mn5g8y8icljx8v10bpc0d0rbfgbxfb1d6r0c3q")))
     (build-system rails-build-system)
     (arguments `(#:precompile-rails-assets? #f))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/info-frontend"))
   #:extra-inputs (list libffi)))

(define-public licence-finder
  (package-with-bundler
   (bundle-package
    (hash (base32 "1nphcv820p8mdbpaz6bzfj9xk1q0114ljf5cxrpllxhw4p2wglaa")))
   (package
     (name "licence-finder")
     (version "release_304")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1nk53h4vcrf4z0bmjmk1rkdq7w3b291mmaarqb37dmhw4d6ay8a1")))
     (build-system rails-build-system)
     (arguments `(#:ruby ,ruby-2.3))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/licence-finder"))))

(define-public local-links-manager
  (package-with-bundler
   (bundle-package
    (hash (base32 "1dz0181vjmfr6x6cm69lchb57a5cnxl0d0llxn13nagdcibqnxa4")))
   (package
     (name "local-links-manager")
     (version "release_138")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "175kw3asyv3v23i3gw89m20dcijnlf26l62ajd09q4y7r9p3mpkw")))
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
   #:extra-inputs (list postgresql
                        libffi)))

(define-public manuals-frontend
  (package-with-bundler
   (bundle-package
    (hash (base32 "0z3zv3lf04pjv2fmg4fyv8a1yfw6v0yrpi6y4nzkzq9sbdi07rgc")))
   (package
     (name "manuals-frontend")
     (version "release_233")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1aplp309nyajz4afasbi62j934glsjamcc19fq67p5vdfyd905vi")))
     (build-system rails-build-system)
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/manuals-frontend"))
   #:extra-inputs (list libffi)))

(define-public manuals-publisher
  (package-with-bundler
   (bundle-package
    (hash (base32 "0c2b3pggajzsxvraf7jjg6k5ivc6bwra1x7bqwp1r9zqlpddgq2d")))
   (package
     (name "manuals-publisher")
     (version "release_1007")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0ssb7jhmww87nxl05f29d665lq603p7f2bmknx3w5zxvzxv8f47w")))
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
     (home-page "https://github.com/alphagov/manuals-publisher"))
   #:extra-inputs (list libffi)))

(define-public maslow
  (package-with-bundler
   (bundle-package
    (hash (base32 "076qdqxw17jqf73y7ncmc6vzrix3j1cpmx732s9kwwaryc2m06m0")))
   (package
     (name "maslow")
     (version "release_213")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0pih036zqxbq3n0d8mfs6kqm8k91a1b6j9ks92f17vzhzc1355dc")))
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
    (hash (base32 "0p6amfzqkfdy011xa4lgzl7bfslh1ddj7fpnqisgakxfbk4mgg87")))
   (package
     (name "policy-publisher")
     (version "release_206")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "056qlg1qcvnncm8w2ghsd6glh8039iwbhqlglagizlfmqd3sib2i")))
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
   #:extra-inputs (list libffi
                        postgresql)))

(define-public publisher
  (package-with-bundler
   (bundle-package
    (hash (base32 "07cc3ddwc2qji7qx5mkmlni8dp8g7d7npkdzkgq6a96whgir0qqf")))
   (package
     (name "publisher")
     (version "release_1858")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1k6zr9z6fhyffp39nyxv3jfs2ddd3q1bfdx6wykq0xd4i7zyv9rb")))
     (build-system rails-build-system)
     (arguments
      `(#:phases
        (modify-phases %standard-phases
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
    (hash (base32 "0ddw555rd2419g17xqa96zhpi63dxr5qbxmpz5lff49yzrsaplg5")))
   (package
     (name "publishing-api")
     (version "release_1075")
     (source
      (github-archive
       #:repository "publishing-api"
       #:commit-ish version
       #:hash (base32 "12jf0684hcmfb20zzar4wnvvydrqyryn6qkvnyp9qq6vy75rbsb8")))
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
                   libffi
                   ;; Required by the pg gem
                   postgresql)))

(define-public publishing-e2e-tests
  (package-with-bundler
   (bundle-package
    (hash
     (base32 "0w1air5z0dhdwbsm5mml1lnvx04k893rln4fypxj6xmvb28aw60i")))
   (package
     (name "publishing-e2e-tests")
     (version "0")
     (source
      (github-archive
       #:repository "publishing-e2e-tests"
       #:commit-ish "16c03fb65aae5cb3df5523fe51abb125375bafb3"
       #:hash (base32 "1pv6nqqc9c69nv3dnpdfjcwq9g9s9disz41sdjsrgzj38m0xclf8")))
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
                   libffi
                   ;; For nokogiri
                   pkg-config
                   libxml2
                   libxslt)))

(define-public release
  (package-with-bundler
   (bundle-package
    (hash (base32 "09s8ax69xk6c744lql8rkkgpamcp5snwr70w70jwjha30vw02s0k")))
   (package
     (name "release")
     (version "release_263")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "00fqkg75ay4r6vikv03b78l530az7v7nba3fg993v7fad5p8dj1g")))
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
   #:extra-inputs (list mariadb
                        libffi)))

(define-public router
  (package
    (name "router")
    (version "release_179")
    (source
     (github-archive
      #:repository name
      #:commit-ish version
      #:hash (base32 "104anjzgyymcrqs5lyhigk6sig228p53sa17a8fvn6iprvlqh932")))
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
    (hash (base32 "1qymvf2w9a2fqngh7jpax270y8ylry7a9h5h83a7gax1a84wvvm5")))
   (package
     (name "router-api")
     (version "release_130")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "01vsy1pdwyw8b875xd882n5k32gv4dfybvidybwh1d883flznbnm")))
     (build-system rails-build-system)
     (arguments `(#:precompile-rails-assets? #f
                  #:ruby ,ruby-2.3))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/router-api"))
   #:extra-inputs (list libffi)))

(define-public rummager
  (package-with-bundler
   (bundle-package
    (hash (base32 "0gqa2jbmgzvcxnjn4zjy5hcx0hncg11ss0d8q6fxk3l38l4rvxcm")))
   (package
     (name "rummager")
     (version "release_1647")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "19sydav1drnb6zq7i303wfnhpj546kaqi4wd8iy1wlgqvk1ix9fk")))
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
    (hash (base32 "1dmw585sjq8alfhvqrv72hjw81jk1i13ljdy96p4vwnjgaxy3w2b")))
   (package
     (name "search-admin")
     (version "release_116")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "13sh9mqvgnabj0z23f3zfwk13nh0qrrcsvv3w4mapndc51li8zrj")))
     (build-system rails-build-system)
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/search-admin"))
   #:extra-inputs (list libffi
                        mariadb)))

(define-public service-manual-frontend
  (package-with-bundler
   (bundle-package
    (hash (base32 "0mpnc37gl0x0l9wkpbp3j71y4dnsy0rz9x9cgav7p908hyw0jlzc")))
   (package
     (name "service-manual-frontend")
     (version "release_107")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "14jqbm6ypbw8bngal6pwaysxjglnvz0kbmwr9m6fpah3wvsck14g")))
     (build-system rails-build-system)
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/service-manual-frontend"))
   #:extra-inputs (list libffi)))

(define-public service-manual-publisher
  (package-with-bundler
   (bundle-package
    (hash (base32 "0hq9bvfvhm15paq43b3vxviqi18dfn29diybg8v696sjd5bv8cr4")))
   (package
     (name "service-manual-publisher")
     (version "release_308")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1z9k24s3gks2gnk071wi37lxjv83l0wnm96a2jfnzn10bglmycvf")))
     (build-system rails-build-system)
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
    (hash (base32 "15374xc7xxqsaijsz9g04r2mh8v3a3145b2qhzx70lq5bgydb8aw")))
   (package
     (name "short-url-manager")
     (version "release_137")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0zck56856db72ha05xffgs4rad4g5rblbjbqc28rkshjshlvsdpj")))
     (build-system rails-build-system)
     (arguments `(#:precompile-rails-assets? #f ;; Asset precompilation fails
                  #:ruby ,ruby-2.3))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/short-url-manager"))
   #:extra-inputs (list libffi)))

(define-public signon
  (package-with-bundler
   (bundle-package
    (hash (base32 "037qyj90l4m60b6md2pndrwhycglkhyc2j81y7xvpx7msza3apkp"))
    (without '("development" "test")))
   (package
     (name "signon")
     (version "release_957")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1ahmfil9fhg8sfyw01v1glv521jqwn4m8jjkv6lrllkj9dlicgh9")))
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
    (hash (base32 "0zwgvccyqr5lvl8qyblx4nl7pmdkwg79nncf3zjdw1j9n1swh3hg")))
   (package
     (name "smart-answers")
     (version "release_3808")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0g9s2511lbvnya4n8r174vk7yfqgi4lzx6vm95vqf5y2zar5d6lc")))
     (build-system rails-build-system)
     (arguments `(#:precompile-rails-assets? #f)) ;; Asset precompilation fails
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/smart-answers"))
   #:extra-inputs (list libffi)))

(define-public specialist-publisher
  (package-with-bundler
   (bundle-package
    (hash (base32 "0nc176a3zg1m8c9pnlq70sqyiyyay1qzxpvnh1yj14mf27m0id06"))
    (without '("development" "test")))
   (package
     (name "specialist-publisher")
     (version "release_863")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0d545cr2pz2dj7cb3wjd89rx52g9rqa32a2vyr0mfmkaja09sf7c")))
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
    (hash (base32 "0ivmdwn8k0rgrdffrn37v59dbmlcdhi5rs9kmhsj203da1pd4y4x")))
   (package
     (name "static")
     (version "release_2749")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "05sn8f7c69b62gznjh76lc40y3czwlv6inlgligx84cj53g1jpv3")))
     (build-system rails-build-system)
     (arguments `(#:precompile-rails-assets? #f
                  #:ruby ,ruby-2.3))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/static"))
   #:extra-inputs (list
                   libffi)))

(define-public support
  (package-with-bundler
   (bundle-package
    (hash (base32 "15kvy2a28hic6hw4sriqsz1xg8x6ncmp3iyw6sm2j3n5f903li9l")))
   (package
     (name "support")
     (version "release_609")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0a35g9birviyq8hd2s0a3jniq7cax9y608s44f178bhrnjgdl40x")))
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
    (hash (base32 "0b41d3adzvcp9qpj13kfvb86wqln3pnmaj15s2q76j9852ff2fsf")))
   (package
     (name "support-api")
     (version "release_142")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0gd498wfpay4lniv5m24n13yda2znb01pkwcqka5m0jh6jnay2rp")))
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
    (hash (base32 "1gflziwyjl59vcp3x9jqjswisbkrwiw61gmnhzdk6r7dnrf8rhmx")))
   (package
     (name "transition")
     (version "release_812")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "08fbpn61c6pmyzq4njwkvcb0x0dclq0j701n11n774ziyf8d8wky")))
     (build-system rails-build-system)
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
    (hash (base32 "082j4blb94c0hxpjl7id79lpyz9bq177rfnhac97cmb0pnzdmib0")))
   (package
     (name "travel-advice-publisher")
     (version "release_309")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1dz0a7pv80n3px1aka0igb0gpdc4bdr6z06q3pbmyy0n1qpqm5j3")))
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
    (hash (base32 "1arihjp9zlwra4vhj82kd6prhsbyhrz97rqpddzfmvw6xs5c1sww")))
   (package
     (name "whitehall")
     (version "release_13160")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1zzndyrwvmalngx01shcxc2wgv7a05gqmxb5whc408p9pkaxavld")))
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
