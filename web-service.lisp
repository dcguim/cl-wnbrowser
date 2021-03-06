;; -*- mode: common-lisp -*-

;; Copyright (c) 2015 The OpenWordNet-PT project
;; This program and the accompanying materials are made available
;; under the terms described in the LICENSE file.

(in-package :cl-wnbrowser)

;;; (setq hunchentoot:*show-lisp-errors-p* t)

(defun get-previous (n &optional (step 10))
  (- n step))

(defun get-next (n &optional (step 10))
  (+ n step))

(defun get-login ()
  (list :login (hunchentoot:session-value :login)))

(defun process-synset (parameters)
  (if (getf parameters :|error|)
      (cl-wnbrowser.templates:synset-invalid
       (append
        (get-login)
        parameters))
      (cl-wnbrowser.templates:synset
       (append
        (get-login)
        parameters))))

(defun make-callback-uri (request-uri)
  (let* ((redirect-uri (format nil "http://~a~a" *base-url* request-uri))
         (callback-uri (format nil "http://~a/wn/callback?destination=~a"
                               *base-url*
                               (hunchentoot:url-encode request-uri))))
    callback-uri))

(defun process-nomlex (nomlex)
  (cl-wnbrowser.templates:nomlex
   (append (get-login) nomlex)))

(defun process-results (result)
  (cl-wnbrowser.templates:result result))

(defun process-error (result)
  (cl-wnbrowser.templates:searcherror result))

(hunchentoot:define-easy-handler (get-root-handler-redirector :uri "/wn") ()
  (hunchentoot:redirect "/wn/"))

(hunchentoot:define-easy-handler (get-root-handler :uri "/wn/") ()
  (cl-wnbrowser.templates:home
   (append
    (get-login)
    (list
     :info (get-root)
     :githubid *github-client-id*))))

(defun disable-caching ()
  (hunchentoot:no-cache))

(defun preprocess-term (term)
  (cond ((= 0 (length term)) "*:*")
        ((string-equal term "*") "*:*")
        (t term)))
 
(hunchentoot:define-easy-handler (get-stats-handler :uri "/wn/stats") ()
  (disable-caching)
  (cl-wnbrowser.templates:stats (list :stats (get-statistics))))

(hunchentoot:define-easy-handler (execute-search-handler :uri "/wn/search")
    (term start debug limit
	  (fq_frame :parameter-type 'list)
          (fq_word_count_pt :parameter-type 'list)
	  (fq_word_count_en :parameter-type 'list)
	  (fq_rdftype :parameter-type 'list)
	  (fq_lexfile :parameter-type 'list))
  (disable-caching)
  (setf (hunchentoot:session-value :term) term)
  (if (is-synset-id term)
      (hunchentoot:redirect (format nil "/wn/synset?id=~a" term))
      (multiple-value-bind
	    (documents num-found facets error)
          (execute-search
           (preprocess-term term)
           :drilldown (make-drilldown :rdf-type fq_rdftype
                                      :lex-file fq_lexfile
                                      :frame fq_frame
                                      :word-count-pt fq_word_count_pt
                                      :word-count-en fq_word_count_en)
           :api "search-documents"
           :start start :limit limit)
	(let* ((start/i (if start (parse-integer start) 0))
	       (limit/i (if limit (parse-integer limit) 10))
	       (request-uri (hunchentoot:request-uri*))
	      (result (if error 
			  (list :error error :term term)
			  (list :debug debug :term term
				:githubid *github-client-id*
				:login (hunchentoot:session-value :login)
				:callbackuri (make-callback-uri request-uri)
				:returnuri request-uri
				:info (get-root)
				:fq_frame fq_frame
				:fq_rdftype fq_rdftype
				:fq_lexfile fq_lexfile
				:fq_word_count_pt fq_word_count_pt
				:fq_word_count_en fq_word_count_en
				:previous (get-previous start/i)
				:next (get-next start/i limit/i)
				:limit limit/i
				:start start/i :numfound num-found
				:facets facets :documents documents))))
	(if (string-equal "application/json" (hunchentoot:header-in* :accept))
	    (progn
	      (setf (hunchentoot:content-type*) "application/json")
	      (with-output-to-string (s)
		(yason:encode-plist result s)))
	    (progn
	      (setf (hunchentoot:content-type*) "text/html")
	      (if error
		  (process-error result)
		  (progn 
		    (hunchentoot:delete-session-value :ids)
		    (process-results result)))))))))
		  
(hunchentoot:define-easy-handler (search-activity-handler :uri "/wn/search-activities")
    (term start debug sf so
          (fq_sum_votes :parameter-type 'list)
          (fq_num_votes :parameter-type 'list)
	  (fq_type :parameter-type 'list)
	  (fq_tag :parameter-type 'list)
	  (fq_action :parameter-type 'list)
	  (fq_status :parameter-type 'list)
	  (fq_doc_type :parameter-type 'list)
          (fq_provenance :parameter-type 'list)
          (fq_user :parameter-type 'list))
  (disable-caching)
  (multiple-value-bind
        (documents num-found facets error)
      (execute-search
       (preprocess-term term)
       :drilldown (make-drilldown-activity
                   :sum_votes fq_sum_votes
                   :num_votes fq_num_votes
                   :type fq_type
                   :tag fq_tag
                   :action fq_action
                   :status fq_status
                   :doc_type fq_doc_type
                   :provenance fq_provenance
                   :user fq_user)
       :api "search-activities" :start start
       :limit "25" :sf sf :so so)

    (let* ((start/i (if start (parse-integer start) 0))
           (request-uri (hunchentoot:request-uri*))
           (result (if error (list :error error :term term)
                       (append (get-login)
                               (list :debug debug 
                                     :info (get-root)
                                     :term term
                                     :githubid *github-client-id*
                                     :login (hunchentoot:session-value :login)
                                     :callbackuri (make-callback-uri request-uri)
                                     :returnuri request-uri
                                     :fq_type fq_type
                                     :fq_num_votes fq_num_votes
                                     :fq_sum_votes fq_sum_votes
                                     :fq_tag fq_tag
                                     :fq_action fq_action
                                     :fq_status fq_status
                                     :fq_doc_type fq_doc_type
                                     :fq_user fq_user
                                     :fq_provenance fq_provenance
                                     :previous (get-previous start/i)
                                     :next (get-next start/i 25)
                                     :so so
                                     :sf sf
                                     :start start/i :numfound num-found
                                     :facets facets
                                     :documents documents)))))
      (if (string-equal "application/json" (hunchentoot:header-in* :accept))
          (progn
            (setf (hunchentoot:content-type*) "application/json")
            (with-output-to-string (s)
              (yason:encode-plist result s)))
          (progn
            (setf (hunchentoot:session-value :term) term)
            (setf (hunchentoot:content-type*) "text/html")
            (if error (process-error (list :error error :term term))
                (cl-wnbrowser.templates:activities result)))))))

(hunchentoot:define-easy-handler (get-synset-handler
				  :uri "/wn/synset") (id debug)
  (disable-caching)
  (let* ((synset (get-synset id))
         (suggestions (get-suggestions id))
         (comments (get-comments id))
         (request-uri (hunchentoot:request-uri*))
	 (term (hunchentoot:session-value :term))
	 (ids (hunchentoot:session-value :ids)))
    (if (string-equal "application/json" (hunchentoot:header-in* :accept))
	  (progn
	    (setf (hunchentoot:content-type*) "application/json")
	    (with-output-to-string (s)
	      (yason:encode-plist (list :comments comments :suggestions suggestions :synset synset) s)))
	  (progn
	    (when (not (string-equal (lastcar ids) id))
	      (setf (hunchentoot:session-value :ids) (append ids (list id))))
	    (setf (hunchentoot:content-type*) "text/html")
	    (process-synset
	     (append (list
		      :info (get-root)
                      :original-id id
		      :ids (last (hunchentoot:session-value :ids) *breadcrumb-size*)
		      :term term
		      :callbackuri (make-callback-uri request-uri)
		      :returnuri request-uri
		      :debug debug
		      :comments comments
		      :suggestions suggestions
		      :githubid *github-client-id*
		      :synset synset)
		     synset))))))

(hunchentoot:define-easy-handler (get-nomlex-handler
				  :uri "/wn/nomlex") (id debug term)
  (setf (hunchentoot:content-type*) "text/html")
  (disable-caching)
  (let ((nomlex (get-nomlex id))
	(term (hunchentoot:session-value :term)))
    (process-nomlex
     (append
      (list :term term
	    :info (get-root)
	    :callbackuri (make-callback-uri (hunchentoot:request-uri*))
	    :debug debug
            :githubid *github-client-id*
	    :nomlex nomlex)
      nomlex))))

(hunchentoot:define-easy-handler (process-suggestion-handler
				  :uri "/wn/process-suggestion") (id doc_type type params return-uri)
  (let ((login (hunchentoot:session-value :login)))
    (if login
        (progn
          (add-suggestion id doc_type type params login)
          (hunchentoot:redirect (hunchentoot:url-decode return-uri)))
        (progn
          (setf (hunchentoot:content-type*) "text/html")
          (format nil "invalid login")))))

(hunchentoot:define-easy-handler (process-comment-handler
				  :uri "/wn/process-comment") (id doc_type text return-uri)
  (let ((login (hunchentoot:session-value :login)))
    (if login
        (progn
          (add-comment id doc_type text login)
          (hunchentoot:redirect (hunchentoot:url-decode return-uri)))
        (progn
          (setf (hunchentoot:content-type*) "text/html")
          (format nil "invalid login")))))

(hunchentoot:define-easy-handler (delete-suggestion-handler
				  :uri "/wn/delete-suggestion") (id return-uri)
  (let ((login (hunchentoot:session-value :login)))
    (if login
        (progn
          (delete-suggestion id)
          (hunchentoot:redirect (hunchentoot:url-decode return-uri)))
        (progn
          (setf (hunchentoot:content-type*) "text/html")
          (format nil "invalid login")))))

(hunchentoot:define-easy-handler (accept-suggestion-handler
				  :uri "/wn/accept-suggestion") (id return-uri)
  (let ((login (hunchentoot:session-value :login)))
    (if login
        (progn
          (accept-suggestion id)
          (hunchentoot:redirect (hunchentoot:url-decode return-uri)))
        (progn
          (setf (hunchentoot:content-type*) "text/html")
          (format nil "invalid login")))))

(hunchentoot:define-easy-handler (reject-suggestion-handler
				  :uri "/wn/reject-suggestion") (id return-uri)
  (let ((login (hunchentoot:session-value :login)))
    (if login
        (progn
          (reject-suggestion id)
          (hunchentoot:redirect (hunchentoot:url-decode return-uri)))
        (progn
          (setf (hunchentoot:content-type*) "text/html")
          (format nil "invalid login")))))

(hunchentoot:define-easy-handler (delete-comment-handler
				  :uri "/wn/delete-comment") (id return-uri)
  (let ((login (hunchentoot:session-value :login)))
    (if login
        (progn
          (delete-comment id)
          (hunchentoot:redirect (hunchentoot:url-decode return-uri)))
        (progn
          (setf (hunchentoot:content-type*) "text/html")
          (format nil "invalid login")))))

(hunchentoot:define-easy-handler (vote-up-handler
				  :uri "/wn/vote-up") (id)
  (let ((login (hunchentoot:session-value :login)))
    (setf (hunchentoot:content-type*) "application/json")
    (if login
        (with-output-to-string (s)
          (yason:encode-plist (add-vote id login 1) s))
        (with-output-to-string (s)
          (yason:encode-plist (list :result "not-authorized") s)))))

(hunchentoot:define-easy-handler (vote-down-handler
				  :uri "/wn/vote-down") (id)
  (let ((login (hunchentoot:session-value :login)))
    (setf (hunchentoot:content-type*) "application/json")
    (if login
        (with-output-to-string (s)
          (yason:encode-plist (add-vote id login -1) s))
        (with-output-to-string (s)
          (yason:encode-plist (list :result "not-authorized") s)))))

(hunchentoot:define-easy-handler (delete-vote-handler
				  :uri "/wn/delete-vote") (id)
  (let ((login (hunchentoot:session-value :login)))
    (when login
      (delete-vote id))
    (setf (hunchentoot:content-type*) "application/json")
    (with-output-to-string (s)
      (yason:encode-plist (list :result "Done") s))))

(hunchentoot:define-easy-handler (github-callback-handler
				  :uri "/wn/callback") (code destination)
  (let ((access-token (get-access-token code))
        (request-uri (when destination (hunchentoot:url-decode destination))))
    (setf (hunchentoot:session-value :login) (get-user-login (get-user access-token)))
    (if request-uri
        (hunchentoot:redirect request-uri)
        (hunchentoot:redirect "/wn/"))))

(hunchentoot:define-easy-handler (sense-tagging-handler
				  :uri "/wn/sense-tagging") (userid)
  (let ((doc (get-sense-tagging)))
    (setf (hunchentoot:content-type*) "text/html")
    (cl-wnbrowser.templates:sense
       (list :userid userid :document doc))))

(hunchentoot:define-easy-handler (sense-tagging-frame-handler
				  :uri "/wn/sense-tagging-frame") (userid)
  (let ((doc (get-sense-tagging)))
    (setf (hunchentoot:content-type*) "text/html")
    (cl-wnbrowser.templates:sense-frame
       (list :userid userid))))

(hunchentoot:define-easy-handler (sense-tagging-details-handler
				  :uri "/wn/sense-tagging-details") (file text word userid)
  (let ((doc (get-sense-tagging-detail file text word))
        (sel (get-sense-tagging-suggestion file text word userid)))
    (setf (hunchentoot:content-type*) "text/html")
    (cl-wnbrowser.templates:sense-details
       (list :selection sel :file file :text text :word word :userid userid :document doc))))

(hunchentoot:define-easy-handler (sense-tagging-process-suggestion-handler
				  :uri "/wn/sense-tagging-process-suggestion") (file text word userid selection comment)
  (add-sense-tagging-suggestion file text word userid selection comment)
  (hunchentoot:redirect (format nil "/wn/sense-tagging-details?file=~a&text=~a&word=~a&userid=~a" file text word userid)))

(hunchentoot:define-easy-handler (get-prototypes-handler :uri "/wn/prototypes") ()
  (cl-wnbrowser.templates:prototypes))

(hunchentoot:define-easy-handler (get-prototypes-analysis-handler :uri "/wn/prototypes/analysis") ()
  (cl-wnbrowser.templates:gloss-analysis (evaluate-glosses)))

(hunchentoot:define-easy-handler (get-prototypes-phrases-handler :uri "/wn/prototypes/phrases") ()
  (cl-wnbrowser.templates:phrases (list :phrases (generate-all-hypernym-phrases))))

(hunchentoot:define-easy-handler (get-prototypes-isolated-vertices-handler :uri "/wn/prototypes/isolated-vertices") ()
  (cl-wnbrowser.templates:isolated-vertices (list :vertices (isolated-vertices))))

(hunchentoot:define-easy-handler (get-prototypes-dijkstra-handler 
                                  :uri "/wn/prototypes/dijkstra-w") (w1 w2 (selected :parameter-type 'hash-table))
  (cl-wnbrowser.templates:dijkstra
   (list :mode "words" 
         :relations *relations* 
         :selected selected
         :w1 w1
         :w2 w2
         :paths (search-paths w1 w2 :mode :words 
                              :relations 
                              (mapcar #'make-keyword (hash-table-keys selected))))))

(hunchentoot:define-easy-handler (get-prototypes-dijkstra-ss-handler 
                                  :uri "/wn/prototypes/dijkstra-s") (w1 w2 (selected :parameter-type 'hash-table))
  (cl-wnbrowser.templates:dijkstra
   (list :mode "synsets" 
         :relations *relations* 
         :selected selected
         :w1 w1
         :w2 w2
         :paths (search-paths w1 w2 :mode :synsets 
                              :relations
                              (mapcar #'make-keyword (hash-table-keys selected))))))

(hunchentoot:define-easy-handler (get-prototypes-fod-handler 
                                  :uri "/wn/prototypes/flngod") (text)
  (cl-wnbrowser.templates:fod
   (list :text text :freeling (if text (call-freeling text) nil))))

(hunchentoot:define-easy-handler (get-prototypes-verbs-handler 
                                  :uri "/wn/prototypes/verbs") (text)
  (cl-wnbrowser.templates:verbs
   (list :portal (check-portal-da-lingua-portuguesa)
	 :verbnet (check-verbnet)
	 :synsetcandidates (check-synset-candidates)
	 :verbnetgold (check-verbnet-gold)
         :dhbb (check-dhbb)
         :swadesh (check-swadesh)
         :propbank (check-propbank)
         :propbanktranslated (check-propbank-translated)
         :ptud (check-pt-ud)
         :intersection (check-intersection)
         :thousandcv (check-thousand-common-verbs)
         :portalaltafreq (check-portal-alta-freq)
         :ptudcleaned (check-pt-ud-cleaned)
         :verbosdg (check-verbos-dg)
         :verbosdgcleaned (check-verbos-dg-cleaned)
	 :nomlexfloating (check-nomlex-floating)
	 :nomlexfloatingtranslated (check-nomlex-floating-translated)
	 :verbocean (check-verbocean))))

(defun start-server (&optional (port 4243))
  (push (hunchentoot:create-folder-dispatcher-and-handler
	 "/wn/st/"
	 (merge-pathnames #p"static/" *basedir*)) hunchentoot:*dispatch-table*)
  (hunchentoot:start
   (make-instance 'hunchentoot:easy-acceptor
		  :access-log-destination (merge-pathnames #p"wn.log" *basedir*)
		  :port port)))
