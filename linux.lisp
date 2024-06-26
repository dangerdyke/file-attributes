(in-package #:org.shirakumo.file-attributes)

(defconstant AT-FDCWD -100)
(defconstant AT-SYMLINK-NOFOLLOW #x100)
(defconstant STATX-MODE  #x00000002)
(defconstant STATX-UID   #x00000008)
(defconstant STATX-GID   #x00000010)
(defconstant STATX-ATIME #x00000020)
(defconstant STATX-MTIME #x00000040)
(defconstant STATX-BTIME #x00000800)
(defconstant STATX-ALL (logior STATX-MODE STATX-UID STATX-GID STATX-ATIME STATX-MTIME STATX-BTIME))

(cffi:defcfun (cstatx "statx") :int
  (dirfd :int)
  (path :string)
  (flags :int)
  (mask :unsigned-int)
  (statx :pointer))

(cffi:defcstruct statx-timestamp
  (sec :int64)
  (nsec :uint32))

(cffi:defcstruct statx
  (mask :uint32)
  (blksize :uint32)
  (attributes :uint64)
  (nlink :uint32)
  (uid :uint32)
  (gid :uint32)
  (mode :uint16)
  (ino :uint64)
  (size :uint64)
  (blocks :uint64)
  (attributes-mask :uint64)
  (atime (:struct statx-timestamp))
  (btime (:struct statx-timestamp))
  (ctime (:struct statx-timestamp))
  (mtime (:struct statx-timestamp))
  (rdev-major :uint32)
  (rdev-minor :uint32)
  (dev-major :uint32)
  (dev-minor :uint32)
  (mount-id :uint64)
  (spare :uint64 :count 13))

(defmacro with-statx ((ptr path mask) &body body)
  `(cffi:with-foreign-object (,ptr '(:struct statx))
     (if (= 0 (cstatx AT-FDCWD (enpath ,path) AT-SYMLINK-NOFOLLOW ,mask ,ptr))
         (progn ,@body)
         (error "Statx failed"))))

(defun statx (path mask)
  (with-statx (statx path mask)
    (cffi:mem-ref statx '(:struct statx))))

(when (cffi:foreign-symbol-pointer "statx")
  (define-implementation access-time (file)
    (unix->universal (getf (getf (statx file STATX-ATIME) 'atime) 'sec)))

  (define-implementation modification-time (file)
    (unix->universal (getf (getf (statx file STATX-MTIME) 'mtime) 'sec)))

  (define-implementation creation-time (file)
    (unix->universal (getf (getf (statx file STATX-BTIME) 'btime) 'sec)))

  (define-implementation group (file)
    (getf (statx file STATX-GID) 'gid))

  (define-implementation owner (file)
    (getf (statx file STATX-UID) 'uid))

  (define-implementation attributes (file)
    (getf (statx file STATX-MODE) 'mode))

  (define-implementation all-fields (file)
    (with-statx (statx file STATX-ALL)
      (cffi:with-foreign-slots ((uid gid mode atime mtime btime) statx (:struct statx))
        (make-fields :access-time (unix->universal (getf atime 'sec))
                     :modification-time (unix->universal (getf mtime 'sec))
                     :creation-time (unix->universal (getf btime 'sec))
                     :group gid
                     :owner uid
                     :attributes mode)))))
