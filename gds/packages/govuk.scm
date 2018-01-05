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

(define-public asset-manager
  (package-with-bundler
   (bundle-package
    (hash (base32 "12h7ma20157mpd7fv8fmxxd3mf2zpcscadwxnhp1n0my2jv6g0fy")))
   (package
     (name "asset-manager")
     (version "release_219")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0p7r7gp5fqh6nksnclg6ivaagjwhxgpfd8zldmgq63ah4sxbcqwh")))
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
    (hash (base32 "075hlkfxcq8f5icgkr4rxvfp2qihi2yl4ic20lsryqicxbd79c5n")))
   (package
     (name "authenticating-proxy")
     (version "release_50")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1qkp3zv4abba0ca0xjxkb6cak3258a100p6bn667kk482mvzxfbd")))
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
    (hash (base32 "1yrcpvhy6sjrs06p050l5bwpzg22mvjkr7sfw6rdmajcnmmxggw4")))
   (package
     (name "bouncer")
     (version "release_221")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "16z17qya0wl48mbw290p37jfbra3fvd5bfr9yf00a7mwvk1i8z3k")))
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
    (hash (base32 "1lh8v8z5ixg619hwzk5g6ix0bwpgg7mcdi32k6achfpa0n4pis11")))
   (package
     (name "calendars")
     (version "release_447")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0x4pbvzrkm84ar2n4jhc0brpfl826xmk6jgvv9nij1qk6smq3pka")))
     (build-system rails-build-system)
     (synopsis "Serves calendars on GOV.UK")
     (description "")
     (license license:expat)
     (home-page "https://github.com/alphagov/calendars"))
   #:extra-inputs (list libffi)))

(define-public collections
  (package-with-bundler
   (bundle-package
    (hash (base32 "0rma5mgx4afm8xnwisyazzcdx1n2f2nm8adhgb8cvjj9b9nr6iqr")))
   (package
     (name "collections")
     (version "release_422")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0rmid60zp8cbx05dzpnvg1c786wrnwah6zaapzsdhhswvqfnkab4")))
     (build-system rails-build-system)
     (synopsis "Collections serves the new GOV.UK navigation and other pages")
     (description "")
     (license license:expat)
     (home-page "https://github.com/alphagov/collections"))
   #:extra-inputs (list libffi)))

(define-public collections-publisher
  (package-with-bundler
   (bundle-package
    (hash (base32 "0l1166aakqajn6rx68c79hvzwaak6nxq0i052ha2gdbyrw55nbh7")))
   (package
     (name "collections-publisher")
     (version "release_296")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "036z8i87ahzrgnds756w8dhy63cb1bpqddhn1ywmmx6x63y1ldga")))
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
    (hash (base32 "0vbmn9jqvvssjgjpbk8xw4nixbid1n441p1vlfpq1yk3b219j0vv")))
   (package
     (name "contacts-admin")
     (version "release_380")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0g4rbv9khc5rcbr8hjiqijddhlh5jz22zbv6nsffjmm21gnp03g5")))
     (build-system rails-build-system)
     (inputs
      `(;; hostname is needed by the redis-lock gem
        ("inetutils" ,inetutils)))
     ;; Asset compilation fails as it tries to connect to Redis
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
    (hash (base32 "1mnh5lsd3s86hv9hdnbvkkg3zj9lyzwnfmsmcgbl9sd0764cz3qj")))
   (package
     (name "content-performance-manager")
     (version "release_358")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "13mmzjf8hpfa77g4vh0c4700zf5cwa71pkkc1ssq8rgalfhbs8z4")))
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
    (hash (base32 "007psvg3nzfy3f60w17b9y30l8ziaivfvsdqqzw7629x5fsw7n84")))
   (package
     (name "content-store")
     (version "release_698")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "15k677s1brbpp6fprq6mxfwx4cwyph8hga05rprjp03jxglshbdd")))
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
    (hash (base32 "0bgvi4g6h6nkhjq9a73ajfcl6w4s80acn8s7vwaidsd8kzrb8ky6")))
   (package
     (name "content-tagger")
     (version "release_660")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0z4xcbv2r4cb0p9x9cxzan9ia76haq6gs68k70wahbppz9934nlk")))
     (build-system rails-build-system)
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/content-tagger"))
   #:extra-inputs (list postgresql
                        libffi)))

(define-public email-alert-api
  (package-with-bundler
   (bundle-package
    (hash (base32 "1dbq6x2jf7g5ww67kddrrbjksshwcb829zjdzizwcxck7gqw1hia")))
   (package
     (name "email-alert-api")
     (version "release_357")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0sanw4qw59xlx6np3ni3scxlwsl7s5fvwfmpm0cc734jc0iwnn70")))
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
    (hash (base32 "19m1k2p9j7a5bldaxly31gxyna10lfx420lrs0smnq1x3bg8a1wj")))
   (package
     (name "email-alert-frontend")
     (version "release_77")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1l1nmfa1s29qn69ynwddiiaybdnxbr41sbwj7wbnyfgsg3kikl2i")))
     (build-system rails-build-system)
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/email-alert-frontend"))
   #:extra-inputs (list libffi)))

(define-public email-alert-service
  (package-with-bundler
   (bundle-package
    (hash (base32 "1z2b15ggn35x2qimc63hwfzs6a84l2fmlcj1dnfvss39ga53g5j2")))
   (package
     (name "email-alert-service")
     (version "release_104")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0irqzikm4nlxqxdmmrpy5q42fpc091fjbwr8ijidlj8cy5pbgkwf")))
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
    (hash (base32 "17x3yb8wahbs2wv44yqk5p7csf9iz0ymfvb26rd7dq2xia859gar")))
   (package
     (name "feedback")
     (version "release_351")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0q2q6fxlsvwq79y2f6jh06v9n2w8ipdm0sw40mcmysjs9yfsdkxd")))
     (build-system rails-build-system)
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/feedback"))
   #:extra-inputs (list libffi)))

(define-public finder-frontend
  (package-with-bundler
   (bundle-package
    (hash (base32 "12mydvnp903fc3423d88azr8mckbkymmc0avlqk4ijx3s7y2qhg2")))
   (package
     (name "finder-frontend")
     (version "release_360")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0b3kzbmb77fbpwr3i9a7wdqkzzkq20whwfwbqy8vkdavb40ziqjb")))
     (build-system rails-build-system)
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/finder-frontend"))
   #:extra-inputs (list libffi)))

(define-public frontend
  (package-with-bundler
   (bundle-package
    (hash (base32 "02kl8mk2q8qcsmv7sprz8gh6davl44fgz3qkyw3xpmnky9kqjmvm")))
   (package
     (name "frontend")
     (version "release_2799")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1r8z3da6f0xycr6k9h2rcm7kvn7avq94ys6r7b19ab7m31cx655z")))
     (build-system rails-build-system)
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/frontend"))))

(define-public government-frontend
  (package-with-bundler
   (bundle-package
    (hash (base32 "0dp2hz241gsp678l9cm820vi6g5bb1pkbaxnmnf17h2pw1fr8s8i")))
   (package
     (name "government-frontend")
     (version "release_573")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0aqjli6m05pm6k0f5jwhk619cpjb5hf9zi8fkrzyqrpb2mamd3hb")))
     (build-system rails-build-system)
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/government-frontend"))
   #:extra-inputs (list libffi)))

(define-public govuk-content-schemas
  (package
    (name "govuk-content-schemas")
    (version "release_672")
    (source
     (github-archive
      #:repository name
      #:commit-ish version
      #:hash (base32 "05abpixqmijanm9fqf5yffkxk63ya6l53cpsld19fhdvay4d1wpf")))
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
    (hash (base32 "1kfxhffszb9aqlsyv6414x4w6jhydhlzfq8z9yk02zrmi2d20rkb")))
   (package
     (name "imminence")
     (version "release_327")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0sqjkqir056rx59fl71vgddqk4a5wbl68apd5ja4pasc1d73fvi5")))
     (build-system rails-build-system)
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/imminence"))
   #:extra-inputs (list libffi)))

(define-public info-frontend
  (package-with-bundler
   (bundle-package
    (hash (base32 "0w05bwcw6ha7aiq7ka78mcblpmbavz4mdb6sap124rfcacix40ml")))
   (package
     (name "info-frontend")
     (version "release_93")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "157qa96r6qgfm626xv1j3irrfn4ybyiz8c7fw28x4m0j6lfjdn7x")))
     (build-system rails-build-system)
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/info-frontend"))
   #:extra-inputs (list libffi)))

(define-public licence-finder
  (package-with-bundler
   (bundle-package
    (hash (base32 "1n8hgx980yv24drj8ikw9kkcjq3vblgxw94zv71x4mxm71zg7hcs")))
   (package
     (name "licence-finder")
     (version "release_315")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0br95n6a186wiz9fkkwqj52mv4jk28hz3pcxnxqrpbn30x90zvpz")))
     (build-system rails-build-system)
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/licence-finder"))))

(define-public local-links-manager
  (package-with-bundler
   (bundle-package
    (hash (base32 "1zg23hq724y1c60gwy5kfkbv87xbcn8x0gv49aw31xk1y8fgdyvc")))
   (package
     (name "local-links-manager")
     (version "release_144")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1042zkkf7larqnizd84sy5jphw38srckwsy6h2y0argw71njb94y")))
     (build-system rails-build-system)
     (inputs
      `(;; hostname is needed by the redis-lock gem
        ("inetutils" ,inetutils)))
     (arguments
      `(#:phases
        (modify-phases %standard-phases
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
    (hash (base32 "011w0vawydl9y3c083r8421aqw8575qm042qzl4vbk31c6lx5xvf")))
   (package
     (name "manuals-frontend")
     (version "release_238")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0064c1afgf98x7lh8hbh2m29ylcwfsqqwsvb0sb5mhzra354w1w0")))
     (build-system rails-build-system)
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/manuals-frontend"))
   #:extra-inputs (list libffi)))

(define-public manuals-publisher
  (package-with-bundler
   (bundle-package
    (hash (base32 "1klrs6fzpfhnqxcnqmiic265mk2mkjn648v3a4s1y8hff8ynif1a")))
   (package
     (name "manuals-publisher")
     (version "release_1015")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0x4gqmprlhjcbqyj7ylz5maxjncp6cacq568k4yy11h2f3zc5s8f")))
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
     (home-page "https://github.com/alphagov/manuals-publisher"))
   #:extra-inputs (list libffi)))

(define-public maslow
  (package-with-bundler
   (bundle-package
    (hash (base32 "1d9479a0gys18ymwcflgfpm3cbjmhg4iy8vj2ziyaklwq9p9c2sa")))
   (package
     (name "maslow")
     (version "release_223")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "19idsixcywrwdw1ngga0x1p7q3kf9751qyrv5jws1lfky8y9k5qz")))
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
    (hash (base32 "100dw7qmbzqdmf81fgqx1859b77iqvmy60sawbrj8a2291i3pyys")))
   (package
     (name "policy-publisher")
     (version "release_213")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0gdb5lx2m03ds4h704v73i4fxf4r4cf2q7j1qwk5cycdv2f3452d")))
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
    (hash (base32 "1y9xl3qv0rymfqc2242swkvdhvvqr54y12sgdjblj8fnm5giz5yi")))
   (package
     (name "publisher")
     (version "release_1879")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "17iy3nflshlh8d94bviricri3ifm9p2qlmhv7fm6jd15cmpv5225")))
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
    (hash (base32 "0nx4rkpzb64wg0fb27hk4a3a23j2hjx7jgpaw1c16sgggq08igkw")))
   (package
     (name "publishing-api")
     (version "release_1087")
     (source
      (github-archive
       #:repository "publishing-api"
       #:commit-ish version
       #:hash (base32 "1n6b96kbw0mjfnfpqdmhp4y96cppgpf4vaqghshndab9d2h7145m")))
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
     (base32 "1ysv8781prbclmf6ralanba5bf0wbwyvv046r9fpacpy950k3yj4")))
   (package
     (name "publishing-e2e-tests")
     (version "0")
     (source
      (github-archive
       #:repository "publishing-e2e-tests"
       #:commit-ish "a7c6e6b0af5eb048b1f0c6b0a43e20f823cca0d4"
       #:hash (base32 "13nfk1w0nslgp5hrwfvzf4f26i1smympnx477l9a6cna40dasfac")))
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
     (arguments '(#:precompile-rails-assets? #f))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/router-api"))
   #:extra-inputs (list libffi)))

(define-public rummager
  (package-with-bundler
   (bundle-package
    (hash (base32 "0p7yfszn150vp5hy9vflwmms7rdgr1jp4lkvycjv7in9xn22z6rz")))
   (package
     (name "rummager")
     (version "release_1668")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0sghqc0yx625dzyr5y75djqvqp34w92z0x79052h1pi1i2nadc49")))
     (build-system rails-build-system)
     (arguments '(#:precompile-rails-assets? #f))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/rummager"))
   #:extra-inputs (list libffi)))

(define-public search-admin
  (package-with-bundler
   (bundle-package
    (hash (base32 "1c0z0l84wa6f5d3jb5j6vxldw5m54mjd91sm5m0pbsy3yh586yns")))
   (package
     (name "search-admin")
     (version "release_125")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0zw0n1hijnkla94pav53cz8xyzwz07izaah5m8jkcajjiy5yf34k")))
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
    (hash (base32 "13nmbskywvn1b5393p5g5faw3yz694bybacm001cjmb9h0dpkg75")))
   (package
     (name "short-url-manager")
     (version "release_146")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0bi1cl1cvzs17sag2a8yzdv1jr3398grc5cgf9033hpysi52q7an")))
     (build-system rails-build-system)
     ;; Asset precompilation fails due to trying to connect to MongoDB
     (arguments '(#:precompile-rails-assets? #f))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/short-url-manager"))
   #:extra-inputs (list libffi)))

(define-public signon
  (package-with-bundler
   (bundle-package
    (hash (base32 "0d1cgdvx927fri2nk6nvpgmrr6cxszx0ppr76i75q7l0725wql9g"))
    (without '("development" "test")))
   (package
     (name "signon")
     (version "release_961")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0s2rxnbckpjffh6n3vxa11g2982g94bhn7wk31n7kcwyhqxl8ff1")))
     (build-system rails-build-system)
     (arguments
      `(#:phases
        (modify-phases %standard-phases
          (add-after 'install 'replace-database.yml
                     ,(use-blank-database.yml)))))
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
    (hash (base32 "0q072frb87bb4ywjcd98rv5ykb77pckpkr625n5abyy1zzy3ig2n")))
   (package
     (name "smart-answers")
     (version "release_3819")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1n5hlvzpcc5fjwalzx59cmiqwrnhf3iaqns652y78w5zayb39ay9")))
     (build-system rails-build-system)
     ;; Asset precompilation fails due to the preload_working_days
     ;; initialiser
     (arguments `(#:precompile-rails-assets? #f))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/smart-answers"))
   #:extra-inputs (list libffi)))

(define-public specialist-publisher
  (package-with-bundler
   (bundle-package
    (hash (base32 "10z0l0d6aq5dhc1j4rfzys30hxcc0sh7l1yczs6rn8xq3s7wgbmd"))
    (without '("development" "test")))
   (package
     (name "specialist-publisher")
     (version "release_866")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0naqkkd4rgskf5pc1djzhk95w1scfr75qcjvdhy1a2c1xqmskwij")))
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
    (hash (base32 "0p5l2x1dhzmjqx5898a8r7kcm110n3lc03b04zwahwdd7x686pzm")))
   (package
     (name "static")
     (version "release_2752")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "08s4yc1c19sr5f8zi24gsh9vss7ciban16crlalxhmgklawkfl40")))
     (build-system rails-build-system)
     (arguments
      '(#:phases
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
    (hash (base32 "0r24i7ppv9fb997gxii4nkxb9ay3y7d244211hmgfjy6pl2rgys9")))
   (package
     (name "support")
     (version "release_621")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1rj2snym7f2hsi4hnp78nr3szmv3hdxnhd65g4a16r20k0h57pv2")))
     (build-system rails-build-system)
     (arguments
      `(#:precompile-rails-assets? #f ;; Asset precompilation fails,
                                      ;; as it tries to connect to
                                      ;; redis
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
    (hash (base32 "0q8n2bvysis352aljwkp22ja45raqnjk4q6pnsl1rc3whd6v51a0")))
   (package
     (name "support-api")
     (version "release_147")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "064im7gdm3x8qyvdv7mlzkwcnsbqv0q47h0x995hh8mr0crhnbav")))
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
    (hash (base32 "16iwp7b3n2ipf4ryn8yj772m61i1cijl8ydd8xag49ix705nlr84")))
   (package
     (name "transition")
     (version "release_822")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "009rldqxa1kd4f9fvswsz5hq7rqn8ks3rhdqjjzb0vddb85v67cc")))
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
    (hash (base32 "0sj8h5vw5i2wqzk39hq3vzixwnmcskhrjsh0m6vcn3d47p8l5l06")))
   (package
     (name "travel-advice-publisher")
     (version "release_317")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "051rxi395wx3v6r7jfkl067abml4ndpf8dgmhk31c4d0sls8dv1x")))
     (build-system rails-build-system)
     (arguments
      `(#:phases
        (modify-phases %standard-phases
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
    (hash (base32 "1jh52yd783xlsix6jcw5bvm4dy23rqmz2mb7ckkr7i5maj50d8h5")))
   (package
     (name "whitehall")
     (version "release_13175")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1f6xxkzh4kpwiwm572zs33bn9nqivxa9fpyc90ax6lmwj8125dq4")))
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
