;;; -*- Mode: Lisp ; Base: 10 ; Syntax: ANSI-Common-Lisp -*-
;;;;; From Interfaces to Classes: Macros

#+xcvb (module (:depends-on ("interface/interface" "interface/box")))

(in-package :interface)

(declaim (optimize (speed 1) (safety 3) (debug 3)))

;;; TODO: handle gf's with or without explicit override

(defclass object-box (box!)
  ((interface :reader class-interface)))

(defmacro define-classified-method (&rest args)
  (apply '%define-classified-method args))
(defun %define-classified-method
    (class interface class-gf interface-gf &key
     interface-argument (extract-interface interface-argument)
     (interface-keyword :interface)
     (value-keyword :value)
     (wrap `(make-instance ',class))
     (unwrap `(box-ref))
     (genericp t))
  (declare (optimize (speed 1) (safety 3) (debug 3)))
  (nest
   (let* ((gf-options (interface-gf-options interface interface-gf))
          (lambda-list (getf gf-options :lambda-list))
          (results (getf gf-options :values))
          (effects (getf gf-options :effects)))
     (assert gf-options)
     (assert lambda-list))
   (when effects)
   (multiple-value-bind (class-lambda-list
                         class-ignorables
                         class-invoker class-arguments
                         class-mappings)
       (lambda-list-mimicker lambda-list)
     (declare (ignore class-invoker class-arguments class-mappings)))
   (multiple-value-bind (interface-lambda-list
                         interface-ignorables
                         interface-invoker interface-arguments
                         interface-mappings)
       (lambda-list-mimicker lambda-list t)
     (declare (ignore interface-ignorables interface-mappings)))
   (multiple-value-bind (class-required class-optionals
                         class-rest class-keys class-allow-other-keys class-aux)
         (alexandria:parse-ordinary-lambda-list class-lambda-list)
     (declare (ignore class-keys class-allow-other-keys class-aux)))
   (multiple-value-bind (interface-required interface-optionals
                         interface-rest interface-keys interface-allow-other-keys interface-aux)
         (alexandria:parse-ordinary-lambda-list interface-lambda-list)
     (declare (ignore interface-keys interface-allow-other-keys interface-aux)))
   (multiple-value-bind (interface-results-lambda-list
                         interface-results-ignorables
                         interface-results-invoker interface-results-arguments
                         interface-results-mappings)
       (lambda-list-mimicker results t)
     (declare (ignore interface-results-invoker interface-results-arguments
                      interface-results-mappings)))
   (multiple-value-bind (class-results-lambda-list
                         class-results-ignorables
                         class-results-invoker class-results-arguments
                         class-results-mappings)
       (lambda-list-mimicker results t)
     (declare (ignore class-results-ignorables class-results-mappings)))
   (multiple-value-bind (interface-results-required interface-results-optionals
                         interface-results-rest interface-results-keys
                         interface-results-allow-other-keys interface-results-aux)
         (alexandria:parse-ordinary-lambda-list interface-results-lambda-list)
     (declare (ignore interface-results-keys interface-results-allow-other-keys
                      interface-results-aux)))
   (multiple-value-bind (class-results-required class-results-optionals
                         class-results-rest class-results-keys
                         class-results-allow-other-keys class-results-aux)
         (alexandria:parse-ordinary-lambda-list class-results-lambda-list)
     (declare (ignore class-results-keys class-results-allow-other-keys
                      class-results-aux)))
   (let ((first-object-index (first (find-if #'integerp effects :key 'car)))))
   (multiple-value-bind (extra-arguments interface-expression)
       (if first-object-index
           (values nil `(class-interface ,(nth first-object-index class-required)))
           (values `(,interface-argument) extract-interface)))
   (let ((interface-var (first interface-required))
         (lpin (length interface-required))
         (lsin (length class-required))
         (lpout (length interface-results-required))
         (lsout (length class-results-required)))
     (assert (plusp lpin))
     (assert (= lpin lsin))
     (assert (= (length interface-optionals) (length class-optionals)))
     (assert (eq (and interface-rest t) (and class-rest t))))
   (loop
     :with lepout = 0 :with lesout = 0
     :for (pin pout) :in effects
     :for (sin sout) :in effects
     :do (assert (eq (integerp pin) (integerp sin)))
         (assert (eq (null pin) (null sin))) ;; new is new
     :when (integerp pin)
       :collect (list sin sout pin pout) :into effective-inputs :end
     :when (integerp pout)
       :collect (list sout sin pout pin) :into effective-outputs :end
     :when (integerp pout)
       :do (incf lepout) :end
     :when (integerp sout)
       :do (incf lesout) :end
     :finally
     (assert (= (- lpout lepout) (- lsout lesout))))
   (return)
   (let* ((required-input-bindings
           (loop :for (esi () epi ()) :in effective-inputs
             :for siv = (nth esi class-required)
             :for piv = (nth epi interface-required)
             :collect `(,piv (,@unwrap ,siv))))
          (required-output-bindings
           (loop :for (eso esi epo ()) :in effective-outputs
             :when (integerp eso)
             :collect `(,(nth eso class-results-required)
                        ,(if (integerp esi)
                             (nth esi class-required)
                             `(,@wrap
                               ,@(when interface-keyword
                                       `(,interface-keyword ,interface-var))
                               ,@(when value-keyword `(,value-keyword))
                               (nth epo interface-results-required))))))
          (ineffective-class-inputs
           (loop :for i :from 1 :below lsin
             :for v :in (rest class-required)
             :unless (find i effective-inputs :key 'first)
             :collect v))
          (ineffective-interface-inputs
           (loop :for i :from 1 :below lpin
             :for v :in (rest interface-required)
             :unless (find i effective-inputs :key 'third)
             :collect v))
          (ineffective-class-outputs
           (loop :for i :below lpout
             :for v :in class-results-required
             :unless (find i effective-outputs :key 'first)
             :collect v))
          (ineffective-interface-outputs
           (loop :for i :below lpout
             :for v :in interface-results-required
             :unless (find i effective-outputs :key 'third)
             :collect v))
          (interface-argument-bindings
           (append
            `((,interface-var ,interface-expression))
            required-input-bindings
            (loop :for ipi :in ineffective-interface-inputs
              :for isi :in ineffective-class-inputs
              :collect `(,ipi ,isi))
            (loop :for (po () pop) :in interface-optionals
              :for (so () sop) :in class-optionals
              :append `((,po ,so) (,sop ,pop)))
            (when interface-rest
              `((,interface-rest ,class-rest)))))
          (class-results-bindings
           (append
            required-output-bindings
            (loop :for ipo :in ineffective-interface-outputs
              :for iso :in ineffective-class-outputs
              :collect `(,iso ,ipo))
            (loop :for (pro () prop) :in interface-results-optionals
              :for (sro () srop) :in class-results-optionals
              :append `((,sro ,pro) (,srop ,prop)))
            (when class-results-rest
              `((,class-results-rest ,interface-results-rest)))))))
   `(,(if genericp 'defmethod 'defun) ,class-gf
      (,@extra-arguments
       ,@(if genericp
             (loop :for x :in (rest class-lambda-list)
               :for i :from 1 :collect
               (if (find i effective-inputs :key 'first)
                   `(,x ,class)
                   x))
             (rest class-lambda-list)))
      (declare (ignore ,@class-ignorables))
      (let* (,@interface-argument-bindings)
        (multiple-value-bind (,@interface-results-lambda-list)
            (,interface-invoker ',interface-gf ,interface-var ,@(rest interface-arguments))
          (declare (ignore ,@interface-results-ignorables))
          (let* (,@class-results-bindings)
            (,class-results-invoker #'values ,@class-results-arguments)))))))

(defmacro define-classified-interface-class
    (name class-interfaces interface-interfaces &optional slots &rest options)
  (let* ((all-class-interfaces (all-super-interfaces class-interfaces))
         (class-gfs (all-interface-generics all-class-interfaces))
         (all-interface-interfaces (all-super-interfaces interface-interfaces))
         (interface-gfs (all-interface-generics all-interface-interfaces))
         (interface-gfs-hash
          (alexandria:alist-hash-table
           (mapcar (lambda (x) (cons (symbol-name x) x)) interface-gfs) :test 'equal))
         (overridden-gfs (find-multiple-clos-options :method options))
         (overridden-gfs-hash
          (alexandria:alist-hash-table
           (mapcar (lambda (x) (cons (second x) (nthcdr 2 x))) overridden-gfs) :test 'eql)))
    `(progn
       (define-interface ,name (stateful::<mutating> ,@class-interfaces)
         ,slots
         ,@options)
       ,@(loop :for class-gf :in class-gfs
           :unless (gethash class-gf overridden-gfs-hash) :append
           (nest
            (let ((class-effects (getf (search-gf-options all-class-interfaces class-gf) :effects))))
            ;; methods that have registered effects as expressible and expressed in our trivial language
            (when class-effects)
            (let ((interface-gf (gethash (symbol-name class-gf) interface-gfs-hash))))
            (when interface-gf)
            (let ((interface-effects (getf (search-gf-options all-interface-interfaces interface-gf) :effects)))
              (assert interface-effects))
            `((define-mutating-method
                  ,name ,class-interfaces ,interface-interfaces
                  ,class-gf ,interface-gf))))))

    (class interface class-gf interface-gf &key
     interface-argument (extract-interface interface-argument)
     (interface-keyword :interface)
     (value-keyword :value)
     (wrap `(make-instance ',class))
     (unwrap `(box-ref))
     (genericp t))