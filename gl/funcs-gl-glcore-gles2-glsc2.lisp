;;; this file is automatically generated, do not edit
;;; generated from files with the following copyright:
;;;
;;; Copyright 2013-2020 The Khronos Group Inc.
;;; SPDX-License-Identifier: Apache-2.0

(in-package #:cl-opengl-bindings)

;;; generated 2023-12-19T22:38:41Z
;;; from gl.xml @ git sha bb9a7d9bd49408d709e7481e34b689db3b13317c, 2023-12-06T16:19:18Z

(defglextfun ("glBlendColor" blend-color 1353) :void
  (red float)
  (green float)
  (blue float)
  (alpha float))

(defglextfun ("glBlendEquation" blend-equation 1354) :void
  (mode enum))

(defglextfun ("glBindRenderbuffer" bind-renderbuffer 1355) :void
  (target enum)
  (renderbuffer uint))

(defglextfun ("glGenRenderbuffers" gen-renderbuffers 1356) :void
  (n sizei)
  (renderbuffers (:pointer uint)))

(defglextfun ("glRenderbufferStorage" renderbuffer-storage 1357) :void
  (target enum)
  (internalformat enum)
  (width sizei)
  (height sizei))

(defglextfun ("glGetRenderbufferParameteriv" get-renderbuffer-parameter-iv 1358) :void
  (target enum)
  (pname enum)
  (params (:pointer int)))

(defglextfun ("glBindFramebuffer" bind-framebuffer 1359) :void
  (target enum)
  (framebuffer uint))

(defglextfun ("glGenFramebuffers" gen-framebuffers 1360) :void
  (n sizei)
  (framebuffers (:pointer uint)))

(defglextfun ("glCheckFramebufferStatus" check-framebuffer-status 1361) enum
  (target enum))

(defglextfun ("glFramebufferTexture2D" framebuffer-texture-2d 1362) :void
  (target enum)
  (attachment enum)
  (textarget enum)
  (texture uint)
  (level int))

(defglextfun ("glFramebufferRenderbuffer" framebuffer-renderbuffer 1363) :void
  (target enum)
  (attachment enum)
  (renderbuffertarget enum)
  (renderbuffer uint))

(defglextfun ("glGetFramebufferAttachmentParameteriv" get-framebuffer-attachment-parameter-iv 1364) :void
  (target enum)
  (attachment enum)
  (pname enum)
  (params (:pointer int)))

(defglextfun ("glGenerateMipmap" generate-mipmap 1365) :void
  (target enum))

(defglextfun ("glProgramBinary" program-binary 1366) :void
  (program uint)
  (binaryFormat enum)
  (binary (:pointer :void))
  (length sizei))

(defglextfun ("glTexStorage2D" tex-storage-2d 1367) :void
  (target enum)
  (levels sizei)
  (internalformat enum)
  (width sizei)
  (height sizei))

(defglextfun ("glGetGraphicsResetStatus" get-graphics-reset-status 1368) enum)

(defglextfun ("glGetnUniformfv" getn-uniform-fv 1369) :void
  (program uint)
  (location int)
  (bufSize sizei)
  (params (:pointer float)))

(defglextfun ("glGetnUniformiv" getn-uniform-iv 1370) :void
  (program uint)
  (location int)
  (bufSize sizei)
  (params (:pointer int)))

(defglextfun ("glReadnPixels" readn-pixels 1371) :void
  (x int)
  (y int)
  (width sizei)
  (height sizei)
  (format enum)
  (type enum)
  (bufSize sizei)
  (data (:pointer :void)))

