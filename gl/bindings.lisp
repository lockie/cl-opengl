;;; -*- Mode: Lisp; indent-tabs-mode: nil -*-
;;;
;;; Copyright (c) 2004, Oliver Markovic <entrox@entrox.org>
;;;   All rights reserved.
;;;
;;; Redistribution and use in source and binary forms, with or without
;;; modification, are permitted provided that the following conditions are met:
;;;
;;;  o Redistributions of source code must retain the above copyright notice,
;;;    this list of conditions and the following disclaimer.
;;;  o Redistributions in binary form must reproduce the above copyright
;;;    notice, this list of conditions and the following disclaimer in the
;;;    documentation and/or other materials provided with the distribution.
;;;  o Neither the name of the author nor the names of the contributors may be
;;;    used to endorse or promote products derived from this software without
;;;    specific prior written permission.
;;;
;;; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
;;; AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
;;; IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
;;; ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
;;; LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
;;; CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
;;; SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
;;; INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
;;; CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
;;; ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
;;; POSSIBILITY OF SUCH DAMAGE.

(in-package #:cl-opengl-bindings)

;;; in case we want to be able to tell whether we are using a cl-opengl with
;;; automatic error checking, push something on *features*
#-cl-opengl-no-check-error(pushnew :cl-opengl-checks-errors *features*)

(define-condition cl-opengl-condition (condition)
  ())

(define-condition function-not-found (error cl-opengl-condition)
  ((function :initarg :function :reader function-not-found.function))
  (:report (lambda (c s)
             (format s "Couldn't find function ~A"
                     (function-not-found.function c)))))

(define-condition opengl-error (simple-error cl-opengl-condition)
  ((error-code :initarg :error-code :reader opengl-error.error-code)
   (error-context :initform nil :initarg :error-context :reader opengl-error.error-context))
  (:report (lambda (c s)
             (if (opengl-error.error-context c)
                 (format s "OpenGL signalled ~A from ~A."
                         (opengl-error.error-code c)
                         (opengl-error.error-context c))
                 (format s "OpenGL signalled ~A."
                         (opengl-error.error-code c))))))

(defvar *traps-already-masked* nil)

(defmacro with-float-traps-masked (() &body body)
  "Mask floating point traps in dynamic scope of BODY, and disable
automatic per-call masking within that scope."
  `(let ((*traps-already-masked* t))
     (float-features:with-float-traps-masked t
       ,@body)))

(defmacro with-float-traps-maybe-masked (() &body body)
  #+cl-opengl-no-masked-traps
  `(progn ,@body)
  #-cl-opengl-no-masked-traps
  `(if *traps-already-masked*
       (progn
         ,@body)
       (float-features:with-float-traps-masked t
         ,@body)))

(defparameter *in-begin* nil)
;; inlining lots of restart-case kills compilation times on SBCL, and
;; doesn't seem to help performance much. Inlining just the *in-begin*
;; check seems to be 10-20% faster when not checking errors, so just
;; inlining that.
(declaim (inline check-error))

(defun check-error (&optional context)
  (declare (optimize speed))
  (unless *in-begin*
    (%check-error context)))

(defun %check-error (&optional context)
  (declare (optimize speed))
  (let ((error-code (foreign-funcall ("glGetError" :library opengl)
                                     :unsigned-int)))
    (unless (zerop error-code)
      (restart-case
          (error 'opengl-error
                 :error-code (cons error-code
                                   (cffi:foreign-enum-keyword '%gl:enum error-code
                                                              :errorp nil))
                 :error-context context)
        (continue () :report "Continue")))))

;; allow deferring automatic error check within a block of code.
(defmacro with-deferred-errors ((name &key force) &body body)
  "Defer automatic glGetError check until end of dynamic scope of BODY,
reporting NAME (not evaluated) as the source of any errors detected.
Nested calls will defer check until end of outermost scope. If
FORCE (evaluated) is not NIL, automatic error checks will be forced on
instead to allow easier localization of errors when debugging instead
of removing the form completely.

Note that BEGIN/END/WITH-PRIMITIVES already defer checks because
glGetError is not allowed within a glBegin/glEnd pair, so this should
not be used in those contexts."
  `(multiple-value-prog1
       (let ((*in-begin* (not ,force)))
         ,@body)
     (check-error ',name)))

;;; Helper macro to define a GL API function and declare it inline.
(defmacro defglfun ((cname lname) result-type &body body)
  `(progn
     (declaim (inline ,lname))
     #-cl-opengl-no-check-error
     (defun ,lname ,(mapcar #'first body)
       (multiple-value-prog1
           (with-float-traps-maybe-masked ()
            (foreign-funcall (,cname :library opengl)
                             ,@(loop for i in body
                                     collect (second i)
                                     collect (first i))
                             ,result-type))
         ,@(cond
             ((string= cname "glGetError") ())
             ((string= cname "glBegin")
              `((setf *in-begin* t)))
             ((string= cname "glEnd")
              `((setf *in-begin* nil)
                (check-error ',lname)))
             (t
              `((check-error ',lname))))))
     #+cl-opengl-no-check-error
     (defun ,lname ,(mapcar #'first body)
       (with-float-traps-maybe-masked ()
        (foreign-funcall (,cname :library opengl)
                         ,@(loop for i in body
                                 collect (second i)
                                 collect (first i))
                         ,result-type)))
     #++(defcfun (,cname ,lname :library opengl) ,result-type ,@body)))

;;;; Extensions

;;; TODO: need to handle multiple contexts.
;;;
;;; TODO: probably should have the option of using directly exported
;;;       functions on platforms that have them, but that would need
;;;       to deal with the possibility of a core being loaded on a
;;;       system with different functions exported than the one on
;;;       which the core was saved.

;;; Set this to a function which knows how to get a GL extension
;;; pointer from the OS: glutGetProcAddress(), SDL_GL_GetProcAddress(),
;;; wglGetProcAddress(), etc.
(defparameter *gl-get-proc-address* nil)

;;; Fallback get-proc-address bindings which should work for common
;;; configurations
;;; TODO: Darwin
#+(or linux freebsd)
(defcfun ("glXGetProcAddress" glx-get-proc-address) :pointer
  (proc-name :string))
#+windows
(defcfun ("wglGetProcAddress" wgl-get-proc-address) :pointer
  (proc-name :string))

(defun gl-get-proc-address (name)
  (funcall (or *gl-get-proc-address*
               #+(or linux freebsd) #'glx-get-proc-address
               #+windows #'wgl-get-proc-address
               #-(or linux freebsd windows) #'cffi:foreign-symbol-pointer)
           name))

(eval-when (:load-toplevel :execute)
  #+clisp (pushnew 'reset-gl-pointers custom:*fini-hooks*)
  #+sbcl (pushnew 'reset-gl-pointers sb-ext:*save-hooks*)
  #+cmu (pushnew 'reset-gl-pointers ext:*before-save-initializations*)
  ;; ECL does not need this since it does not save images
  #-(or clisp sbcl cmu ecl)
  (warn "Don't know how to setup a hook before saving cores on this Lisp."))

;;;; Bart's version of DEFGLEXTFUN.

#-(and)
(defparameter *gl-extension-resetter-list* nil)

;;; FIXME? There's a possible race condition here, but this function
;;; is intended to be called while saving an image, so if someone is
;;; still calling GL functions we lose anyway...
#-(and)
(defun reset-gl-pointers ()
  (format t "~&;; resetting extension pointers...~%")
  (mapc #'funcall *gl-extension-resetter-list*)
  (setf *gl-extension-resetter-list* nil))

#-(and)
(defmacro defglextfun ((cname lname) return-type &body args)
  (with-unique-names (pointer)
    `(let ((,pointer (null-pointer)))
       (defun ,lname ,(mapcar #'car args)
         (when (null-pointer-p ,pointer)
           (setf ,pointer (%gl-get-proc-address ,cname))
           (assert (not (null-pointer-p ,pointer)) ()
                   "Couldn't load symbol ~A~%" ,cname)
           (format t "Loaded function pointer for ~A: ~A~%" ,cname ,pointer)
           (push (lambda () (setf ,pointer (null-pointer)))
                 *gl-extension-resetter-list*))
         (foreign-funcall-pointer
          ,pointer
          (:library opengl)
          ,@(loop for arg in args collect (second arg) collect (first arg))
          ,return-type)))))

;;;; Thomas's version of DEFGLEXTFUN.
#++
(defun reset-gl-pointers ()
  (do-external-symbols (sym (find-package '#:%gl))
    (let ((dummy (get sym 'proc-address-dummy)))
      (when dummy
        (setf (fdefinition sym) dummy)))))
#++
(defun generate-gl-function (foreign-name lisp-name result-type body &rest args)
  (let ((address (gl-get-proc-address foreign-name))
        (arg-list (mapcar #'first body)))
    (when (or (not (pointerp address)) (null-pointer-p address))
      (error 'function-not-found :function foreign-name))
    (compile lisp-name
             `(lambda ,arg-list
                (multiple-value-prog1
                    (with-float-traps-maybe-masked ()
                      (foreign-funcall-pointer
                       ,address
                       (:library opengl)
                       ,@(loop for i in body
                               collect (second i)
                               collect (first i))
                       ,result-type))
                  #-cl-opengl-no-check-error
                  (check-error ',lisp-name))))
    (apply lisp-name args)))
#++
(defmacro defglextfun ((foreign-name lisp-name) result-type &rest body)
  (let ((args-list (mapcar #'first body)))
    `(progn
       (declaim (notinline ,lisp-name))
       (defun ,lisp-name ,args-list
         (generate-gl-function ,foreign-name  ',lisp-name ',result-type
                               ',body ,@args-list))
       (setf (get ',lisp-name 'proc-address-dummy) #',lisp-name)
       ',lisp-name)))

;;;; yet another version of DEFGLEXTFUN

(defun reset-gl-pointers ()
  (replace *ext-thunks* *init-ext-thunks*))

(defun missing-thunk (x)
  (lambda (&rest r)
    ;; should only see this if you didn't load all of the binding
    ;; definition files, and tried to call a function from one of the
    ;; missing files
    (declare (ignore r))
    (error "missing extension thunk ~d?" x)))

;; some users used defglextfun in their own code, so keep old behavior
;; around
(defun generate-gl-function/old (foreign-name lisp-name result-type body
                                 &rest args)
  (let ((address (gl-get-proc-address foreign-name))
        (arg-list (mapcar #'first body)))
    (when (or (not (pointerp address)) (null-pointer-p address))
      (error 'function-not-found :function foreign-name))
    (compile lisp-name
             `(lambda ,arg-list
                (multiple-value-prog1
                    (with-float-traps-maybe-masked ()
                      (foreign-funcall-pointer
                       ,address
                       (:library opengl)
                       ,@(loop for i in body
                               collect (second i)
                               collect (first i))
                       ,result-type))
                  #-cl-opengl-no-check-error
                  (check-error ',lisp-name))))
    (apply lisp-name args)))

(defun generate-ext-thunk (index foreign-name lisp-name result-type args)
  (let ((arg-list (mapcar #'first args)))
    (flet ((decl (arg)
             (destructuring-bind (name type) arg
               (case type
                 ((float clampf) `(type single-float ,name))
                 ((double clampd) `(type single-float ,name))
                 ((char char-arb byte)
                  `(declare (type (signed-byte 8) ,name)))
                 ((ubyte)
                  `(declare (type (unsigned-byte 8) ,name)))
                 ((short)
                  `(declare (type (signed-byte 16) ,name)))
                 ((ushort half half-arb half-nv)
                  `(declare (type (unsigned-byte 16) ,name)))
                 ((int sizei clampx fixed)
                  `(declare (type (unsigned-byte 32) ,name)))
                 ((handle-arb uint)
                  `(declare (type (unsigned-byte 32) ,name)))
                 ((int64 int64-ext)
                  `(declare (type (signed-byte 64) ,name)))
                 ((uint64 uint64-ext)
                  `(declare (type (unsigned-byte 64) ,name)))
                 ((sync
                   debugproc debugproc-arb debugproc-amd debugprockhr
                   egl-image-oes)
                  `(declare (type foreign-pointer ,name))))))
           ;; use a simpler type if wrapper already translated it
           (replace-type (type)
             (case type
               (offset-or-pointer 'sizeiptr)
               (t type))))
      `(lambda (&rest r)
         (let ((address (gl-get-proc-address ,foreign-name)))
           (declare (type sb-sys:system-area-pointer address))
           (when (or (not (pointerp address)) (null-pointer-p address))
             (error 'function-not-found :function ,foreign-name))
           (setf (aref *ext-thunks* ,index)
                 (lambda ,arg-list
                   (declare (optimize speed)
                            ,@(remove nil
                                      (mapcar #'decl
                                              args)))
                   (multiple-value-prog1
                       (with-float-traps-maybe-masked ()
                         (foreign-funcall-pointer
                          address
                          (:library opengl)
                          ,@(loop for (name type) in args
                                  collect (replace-type type)
                                  collect name)
                          ,result-type))
                     #-cl-opengl-no-check-error
                     (check-error ',lisp-name))))
           (apply (aref *ext-thunks* ,index) r))))))

(defun generate-gl-function/new (index foreign-name lisp-name result-type args)
  (let ((args-list (mapcar #'first args)))
    (flet ((maybe-cast (arg)
             ;; todo: possibly should add type checks as well for
             ;; remaining types?
             (destructuring-bind (name type) arg
               (case type
                 ((int sizei) `(truncate ,name))
                 ((float clampf) `(coerce ,name 'single-float))
                 ((double clampd) `(coerce ,name 'double-float))
                 ((offset-or-pointer) `(if (pointerp ,name)
                                           (pointer-address ,name)
                                           ,name))
                 (t name)))))
      `(progn
         ;; generate a thunk and store it in the thunk init vector
         (setf (aref *init-ext-thunks* ,index)
               ,(generate-ext-thunk index foreign-name lisp-name
                                    result-type args))
         ;; and save it into the active thunk vector too, so we don't
         ;; need a separate copy step after loading the bindings and
         ;; so C-c C-c on definitions works as expected when running
         (setf (aref *ext-thunks* ,index) (aref *init-ext-thunks* ,index))
         ;; generate an inline function that does type translations
         ;; and calls the thunk
         (declaim (inline ,lisp-name))
         (defun ,lisp-name ,args-list
           (funcall (aref *ext-thunks* ,index)
                    ,@ (loop for arg in args
                             collect (maybe-cast arg))))))))

(defmacro defglextfun ((foreign-name lisp-name &optional index) result-type
                       &rest body)
  (if index
      (generate-gl-function/new index foreign-name lisp-name result-type body)
      ;; preserve old behavior for user code that calls it (user code
      ;; can't be updated to use new version, since it relies on
      ;; predefined fixed indices currently)
      (let ((args-list (mapcar #'first body)))
        `(progn
           (declaim (notinline ,lisp-name))
           (defun ,lisp-name ,args-list
             (generate-gl-function ,foreign-name  ',lisp-name ',result-type
                                   ',body ,@args-list))
           (setf (get ',lisp-name 'proc-address-dummy) #',lisp-name)
           ',lisp-name))))
