from librados cimport rados_ioctx_t, rados_list_ctx_t, rados_xattrs_iter_t

cdef make_ex(int ret, str msg)

cdef class Rados:

    cdef void *cluster
    cdef int   state

cdef class PoolStats:
    cdef readonly int num_bytes
    cdef readonly int num_kb
    cdef readonly int num_objects
    cdef readonly int num_object_clones
    cdef readonly int num_object_copies
    cdef readonly int num_objects_missing_on_primary
    cdef readonly int num_objects_unfound
    cdef readonly int num_objects_degraded
    cdef readonly int num_rd
    cdef readonly int num_rd_kb
    cdef readonly int num_wr
    cdef readonly int num_wr_kb

cdef class Pool:

    cdef rados_ioctx_t ctx
    cdef char         *name

    cdef char *_read(self, char *key, int length, int offset)

cdef class ObjectIterator:

    cdef Pool              pool
    cdef rados_list_ctx_t  ctx

cdef class ObjectXAttrs:

    cdef Object obj

cdef class ObjectXAttrsIterator:

    cdef Object              obj
    cdef rados_xattrs_iter_t ctx

cdef class Object:

    cdef Pool  pool
    cdef readonly char *key
    cdef int   pos
    cdef int   state
