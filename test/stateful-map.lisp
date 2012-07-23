#+xcvb (module (:depends-on ("package" "functional-map")))

(in-package :lisp-stateful-datastructure-test)

(declaim (optimize (speed 1) (debug 3) (space 3)))

(defsuite* (test-stateful-map
            :in test-suite
            :documentation "Testing pure functional maps"))

(defmacro with-map ((m i &optional (init '())) &body body)
  `(let ((,m (alist-map* ,i ,init))) ,@body (map-alist i ,m)))

(defmethod interface-test ((i <map>))
  (X 'interface-test *package* i)
  ;;; TODO: test each and every function in the API
  (X 'empty)
  (is (null (map-alist i (empty i))))
  (is (empty-p i (alist-map* i ())))

  (X 'lookup)
  (is (equal "12"
             (lookup
              i
              (alist-map*
               i '((57 . "57") (10 . "10") (12 . "12")))
              12)))
  (loop :for (k . v) :in *al-1* :with m = (alist-map* i *al-1*) :do
    (is (eq v (lookup i m k))))

  (X 'alist-map*-and-back)
  (is (equal-alist *alist-10-latin*
                   (map-alist i (alist-map* i *alist-10-latin*))))
  (is (equal-alist *alist-10-latin*
                   (map-alist i (alist-map* i *alist-10-latin*))))
  (is (equal-alist *alist-100-decimal*
                   (map-alist i (alist-map* i *al-1*))))
  (is (equal-alist *al-5*
                   (with-map (m2 i *al-2*)
                     (is (eq m2 (join i m2 (alist-map i *al-3*)))))))

  (X 'insert)
  (is (equal '((0)) (with-map (m i) (insert i m 0 nil))))
  (is (equal-alist
       '((1 . "1") (2 . "2") (3 . "3"))
       (with-map (m i '((1 . "1") (3 . "3"))) (insert i m 2 "2"))))

  (X 'insert-and-join)
  (is (equal-alist
       '((0 . "0") (1 . "1") (2 . "2"))
       (with-map (m i '((1 . "1")))
         (join i m (alist-map* i '((2 . "2"))))
         (insert i m 0 "0"))))

  (X 'insert-and-size)
  (with-map (m i *al-1*)
    (insert i m 101 "101")
    (is (= 101 (size i m))))

  (X 'drop)
  (with-map (m i)
    (is (equal '(nil nil)
               (multiple-value-list (drop i m 0)))))
  (is (equal (with-map (m i '((1 . "1") (2 . "2")))
               (is (equal '("1" t) (multiple-value-list (drop i m 1)))))
             '((2 . "2"))))
  (with-map (m i *al-1*)
    (is (equal '("42" t) (multiple-value-list (drop i m 42))))
    (is (= (size i m) 99)))

  (X 'drop-and-size)
  (with-map (m i *alist-100-decimal*)
    (is (equal '("57" t) (multiple-value-list (drop i m 57))))
    (is (= (size i m) 99)))

  (X 'first-key-value)
  (with-map (m i)
    (is (equal '(nil nil nil)
               (multiple-value-list (first-key-value i m)))))
  (with-map (m i *al-2*)
    (multiple-value-bind (k v b) (first-key-value i m)
      (multiple-value-bind (vv bb) (lookup <alist> *al-2* k)
        (is (equal b t))
        (is (equal bb t))
        (is (equal v vv)))))
  (with-map (m i *alist-100-latin*)
    (multiple-value-bind (k v b) (first-key-value i m)
      (multiple-value-bind (vv bb) (lookup <alist> *alist-100-latin* k)
        (is (equal b t))
        (is (equal bb t))
        (is (equal v vv)))))

  (X 'decons)
  (with-map (m i)
    (is (equal '(() () ()) (multiple-value-list (decons i m)))))
  (with-map (m i *alist-10-latin*)
    (multiple-value-bind (b k v) (decons i m)
      (is (eq b t))
      (is (equal (list v t)
                 (multiple-value-list (lookup <alist> *alist-10-latin* k))))
      (is (equal '(nil nil)
                 (multiple-value-list (lookup i m k))))
      (is (= (size i m) 9))))

  (X 'fold-left)
  (is (eql nil (fold-left i (empty i) (constantly 1) nil)))
  (is (eql t (fold-left i (empty i) (constantly 1) t)))
  (is (equal-alist
       '((2 . "2") (1 . "1") (20 . "20") (30 . "30"))
       (with-map (m i '((20 . "20") (30 . "30")))
         (fold-left
          i (alist-map* i (make-alist 2))
          #'(lambda (n k v) (declare (ignore n)) (insert i m k v))
          nil))))

    ;;; CONVERT FROM PURE TO STATEFUL FROM HERE ON...
  (X 'fold-left-and-size)
  (with-map (m i *alist-100-latin*)
    (fold-left i (alist-map* i *alist-100-decimal*)
               #'(lambda (n k v) (declare (ignore n)) (insert i m k v))
               nil)
    (is (= 100 (size i m))))

  (X 'fold-right)
  (is (eql nil (fold-right i (empty i) (constantly t) nil)))
  (is (eql t (fold-right i (empty i) (constantly t) t)))
  (is (equal-alist
       '((1 . "1") (2 . "2") (20 . "20") (30 . "30"))
       (with-map (m i '((20 . "20") (30 . "30")))
         (fold-right
          i (alist-map* i (make-alist 2))
          #'(lambda (k v n) (declare (ignore n)) (insert i m k v))
          nil))))

  (X 'for-each)
  (is (eql nil (while-collecting (c)
                 (for-each i (empty i) #'(lambda (k v) (c (cons k v)))))))
  (is (equal-alist
       *alist-10-latin*
       (while-collecting (c)
         (with-output-to-string (o)
           (for-each i (alist-map* i *alist-10-latin*)
                     #'(lambda (k v) (c (cons k v))))))))
  (is (= 1129 (length (with-output-to-string (o)
                        (for-each i (alist-map* i *alist-100-english*)
                                  #'(lambda (x y)
                                      (format o "~A~A" x y)))))))

  (X 'join)
  (is (equal '() (with-map (m i) (join i m (empty i)))))
  (is (equal-alist '((1 . "1") (2 . "2") (5 . "5") (6 . "6"))
                   (with-map (m i '((1 . "1") (2 . "2")))
                     (join i m (alist-map* i '((5 . "5") (6 . "6")))))))

  (X 'join-and-size)
  (with-map (m i *alist-10-latin*)
    (join i m (alist-map* i *alist-100-latin*))
    (is (= 100 (size i m))))

  (X 'divide-and-join)
  (multiple-value-bind (x y) (divide i (empty i))
    (is (empty-p i x))
    (is (empty-p i y)))
  (with-map (m i *alist-10-latin*)
    (multiple-value-bind (x y) (divide i m)
      (is (eq m y))
      (is (equal-alist *alist-10-latin*
                       (append (map-alist i x) (map-alist i y))))))

  (X 'divide-and-size)
  (multiple-value-bind (x y)
      (divide i (alist-map* i '()))
    (is (empty-p i x))
    (is (empty-p i y)))
  (multiple-value-bind (x y)
      (divide i (alist-map* i '((1 . "1"))))
    (is (empty-p i x))
    (is (= 1 (size i y))))
  (multiple-value-bind (x y)
      (divide i (alist-map* i *alist-100-latin*))
    (let ((sx (size i x)) (sy (size i y)))
      (is (plusp sx))
      (is (plusp sy))
      (is (= 100 (+ sx sy)))))

  (X 'size)
  (is (= 0 (size i (empty i))))
  (is (= 100 (size i (alist-map* i *alist-100-decimal*))))
  (with-map (m i *alist-100-decimal*)
    (decons i m)
    (is (= 99 (size i m))))

  ;; (X 'join/list)
  ;; TODO: add tests


  (X 'divide/list)
  ;; TODO: add more tests
  (is (null (divide/list i (empty i))))

  (X 'update-key)
  ;; TODO: add more tests
  (is (null (update-key i (empty i) 0 (constantly nil))))

  (X 'map/2)
  ;; TODO: add more tests
  (is (empty-p i (map/2 i (constantly t) (empty i) (empty i))))

  (X 'convert)
  (is (null (convert <alist> i (empty i))))
  (is (equal-alist *alist-10-latin*
                   (convert <alist> i (convert i <alist> *alist-10-latin*))))

  (X 'iterator)
  (is (equal-alist *alist-10-latin*
                   (map-alist i
                              (flow i i (alist-map* i *alist-10-latin*) (empty i)))))
  t)

(defmethod interface-test :after ((i <number-map>))
  (let* ((a1 (make-alist 1000 "~@R"))
         (a2 (shuffle-list a1))
         (m1 (alist-map* i a1))
         (m2 (alist-map* i a2)))
    (is (= 10 (node-height m1)))
    (is (<= 10 (node-height m2) 15))
    (is (= 1000 (size i m1)))
    (is (= 1000 (size i m2)))))

(defparameter <denm> (<encoded-key-map>
                      :base-interface <number-map>
                      :key-encoder #'(lambda (dk) (* dk 2))
                      :key-decoder #'(lambda (ek) (/ ek 2))))

(deftest test-pure-map-interfaces ()
  (dolist (i (list <number-map> <hash-table> <denm>))
    (interface-test i)))