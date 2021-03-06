;; -*- mode: common-lisp -*-

;; Copyright (c) 2015 The OpenWordNet-PT project
;; This program and the accompanying materials are made available
;; under the terms described in the LICENSE file.

(in-package :cl-wnbrowser)

(defun get-synset-word-en (id)
  "Returns the FIRST entry in the word_en property for the given SYNSET-ID"
  (car (getf (get-synset id) :|word_en|)))

(defun get-synset-word (id)
  "If the synset has word_pt entries, returns the first one; otherwise
returns the first entry in word_en."
  (let* ((synset (get-synset id))
         (word-pt (car (getf synset :|word_pt|)))
         (word-en (car (getf synset :|word_en|))))
    (if word-pt word-pt word-en)))

(defun get-synset-gloss (id)
  "If the synset has word_pt entries, returns the first one; otherwise
returns the first entry in word_en."
  (let* ((synset (get-synset id))
         (gloss-pt (car (getf synset :|gloss_pt|)))
         (gloss-en (car (getf synset :|gloss_en|))))
    (if gloss-pt gloss-pt gloss-en)))

(defun get-search-query-plist (q drilldown limit start sort-field sort-order fl)
  (remove
   nil
   (append 
    (list
     (when q (cons "q" q))
     (when fl (cons "fl" fl))
     (when start (cons "start" start))
     (when sort-field (cons "sf" sort-field))
     (when sort-order (cons "so" sort-order))
     (when (and limit (parse-integer limit :junk-allowed t))
           (cons "limit" limit)))
    (when drilldown drilldown))))

(defun execute-search-query (term &key drilldown limit sort-field sort-order (start 0) fl (api "search-documents"))
  (call-rest-method
   api
   :parameters (get-search-query-plist term drilldown limit start sort-field sort-order fl)))

(defun delete-suggestion (id)
  (call-rest-method
   (format nil "delete-suggestion/~a" (drakma:url-encode id :utf-8))
   :parameters (list (cons "key" *ownpt-api-key*))))

(defun accept-suggestion (id)
  (call-rest-method
   (format nil "accept-suggestion/~a" (drakma:url-encode id :utf-8))
   :parameters (list (cons "key" *ownpt-api-key*))))

(defun reject-suggestion (id)
  (call-rest-method
   (format nil "reject-suggestion/~a" (drakma:url-encode id :utf-8))
   :parameters (list (cons "key" *ownpt-api-key*))))

(defun delete-comment (id)
  (call-rest-method
   (format nil "delete-comment/~a" (drakma:url-encode id :utf-8))
   :parameters (list (cons "key" *ownpt-api-key*))))

(defun add-suggestion (id doc-type type param login)
  (call-rest-method 
   (format nil "add-suggestion/~a" (drakma:url-encode id :utf-8))
   :parameters (list (cons "doc_type" doc-type)
                     (cons "suggestion_type" type)
                     (cons "params" param)
                     (cons "key" *ownpt-api-key*)
                     (cons "user" login))))

(defun add-comment (id doc-type text login)
  (call-rest-method 
   (format nil "add-comment/~a" (drakma:url-encode id :utf-8))
   :parameters (list (cons "doc_type" doc-type)
                     (cons "text" text)
                     (cons "key" *ownpt-api-key*)
                     (cons "user" login))))

(defun get-suggestions (id)
  (get-docs (call-rest-method (format nil "get-suggestions/~a" id))))

(defun get-comments (id)
  (get-docs (call-rest-method (format nil "get-comments/~a" id))))

(defun delete-vote (id)
  (call-rest-method (format nil "delete-vote/~a" id)
                    :parameters (list (cons "key" *ownpt-api-key*))))

(defun add-vote (id user value)
  (call-rest-method (format nil "add-vote/~a" id)
                    :parameters (list
                                 (cons "user" user)
                                 (cons "value" (format nil "~a" value))
                                 (cons "key" *ownpt-api-key*))))
    
(defun get-document-by-id (doctype id)
  (call-rest-method (format nil "~a/~a" doctype (drakma:url-encode id :utf-8))))

(defun request-successful? (result)
  (not (string-equal "SolrError" (getjso "name" result))))

(defun get-error-reason (result)
  (getjso "message" result))

(defun get-docs (result)
  (mapcar #'(lambda (row) (getjso "doc" row))
	  (getjso "rows" result)))

(defun get-num-found (result)
  (getjso "total_rows" result))

(defun get-facet-fields (response)
  (getjso "counts" response))

(defun make-drilldown (&key rdf-type lex-file word-count-pt word-count-en frame)
  "Creates the appropriate PLIST that should be fed to SOLR out of the
list of facet filters specified in the parameters RDF-TYPE and
LEX-FILE."
  (append
   (when frame
     (mapcar #'(lambda (entry)
		 (cons "drilldown"
                       (format nil "[\"wn30_frame\",\"~a\"]" entry)))
	     frame))
   (when word-count-pt
     (mapcar #'(lambda (entry)
		 (cons "drilldown"
                       (format nil "[\"word_count_pt\",\"~a\"]" entry)))
	     word-count-pt))
   (when word-count-en
     (mapcar #'(lambda (entry)
		 (cons "drilldown"
                       (format nil "[\"word_count_en\",\"~a\"]" entry)))
	     word-count-en))
   (when rdf-type
       (mapcar #'(lambda (entry)
                   (cons "drilldown"
                         (format nil "[\"rdf_type\",\"~a\"]" entry)))
	     rdf-type))
   (when lex-file
     (mapcar #'(lambda (entry)
		 (cons "drilldown"
                       (format nil "[\"wn30_lexicographerFile\",\"~a\"]"
                               entry)))
	     lex-file))))

(defun make-drilldown-activity (&key tag type action status doc_type user provenance sum_votes num_votes)
  (append
   (when sum_votes
     (mapcar #'(lambda (entry)
		 (cons "drilldown"
                       (format nil "[\"sum_votes\",\"~a\"]" entry)))
	     sum_votes))
   (when num_votes
     (mapcar #'(lambda (entry)
		 (cons "drilldown"
                       (format nil "[\"vote_score\",\"~a\"]" entry)))
	     num_votes))
   (when tag
     (mapcar #'(lambda (entry)
		 (cons "drilldown"
                       (format nil "[\"tags\",\"~a\"]" entry)))
	     tag))
   (when provenance
     (mapcar #'(lambda (entry)
		 (cons "drilldown"
                       (format nil "[\"provenance\",\"~a\"]" entry)))
	     provenance))
   (when type
     (mapcar #'(lambda (entry)
		 (cons "drilldown"
                       (format nil "[\"type\",\"~a\"]" entry)))
	     type))
   (when action
     (mapcar #'(lambda (entry)
		 (cons "drilldown"
                       (format nil "[\"action\",\"~a\"]" entry)))
	     action))
   (when status
     (mapcar #'(lambda (entry)
		 (cons "drilldown"
                       (format nil "[\"status\",\"~a\"]" entry)))
	     status))
   (when doc_type
     (mapcar #'(lambda (entry)
		 (cons "drilldown"
                       (format nil "[\"doc_type\",\"~a\"]" entry)))
	     doc_type))
   (when user
     (mapcar #'(lambda (entry)
		 (cons "drilldown"
                       (format nil "[\"user\",\"~a\"]"
                               entry)))
	     user))))

(defun execute-search (term &key drilldown api start limit sf so fl)
  (let* ((result (execute-search-query term
                                         :drilldown drilldown
                                         :api api
                                         :start start
                                         :limit limit
                                         :sort-field sf
                                         :fl fl
                                         :sort-order so))
	 (success (request-successful? result)))
    (if success
	(values
	 (get-docs result)
	 (get-num-found result)
	 (get-facet-fields result)
	 nil)
	(values nil nil nil (get-error-reason result)))))

(defun get-synset-ids (term drilldown start limit)
  (let* ((result (execute-search-query term
                                         :drilldown drilldown
                                         :api "search-documents"
                                         :start start
                                         :limit limit
                                         :fl "doc_id"))
	 (success (request-successful? result)))
    (if success
        (mapcar (lambda (s) (getf s :|doc_id|)) (get-docs result))
        nil)))

(defun get-synset (id)
  (get-document-by-id "synset" id))

(defun get-nomlex (id)
  (get-document-by-id "nomlex" id))

(defun get-sense-tagging ()
  (call-rest-method "sense-tagging"
                    :parameters (list (cons "file" "bosque.json"))))

(defun get-sense-tagging-detail (file text word)
  (call-rest-method "sense-tagging-detail"
                    :parameters (list (cons "file" file)
                                      (cons "text" text)
                                      (cons "word" word))))

(defun get-root ()
  (call-rest-method ""))

(defun get-statistics ()
  (call-rest-method "statistics"))

(defun call-rest-method/stream (method &key parameters)
  "Alternative to CALL-REST-METHOD that uses a stream; this is more memory efficient, but it may cause problems if YASON:PARSE takes too long to parse the stream and the stream may be cut due to timeout."
    (let* ((stream (drakma:http-request
                   (format nil "~a/~a" *ownpt-api-uri* method)
                   :parameters parameters
		   :external-format-out :utf-8
                   :method :get
                   :connection-timeout 120
                   :want-stream t)))
    (setf (flexi-streams:flexi-stream-external-format stream) :utf-8)
    (let ((obj (yason:parse stream
			    :object-as :plist
			    :object-key-fn #'make-keyword)))
      (close stream)
      obj)))
  
(defun call-rest-method (method &key parameters)
    (let ((octets (drakma:http-request
                   (format nil "~a/~a" *ownpt-api-uri* method)
                   :parameters parameters
		   :external-format-out :utf-8
                   :method :get
                   :connection-timeout 120
                   :want-stream nil)))
      (yason:parse
       (flexi-streams:octets-to-string octets :external-format :utf-8)
                   :object-as :plist
                   :object-key-fn #'make-keyword)))

  
