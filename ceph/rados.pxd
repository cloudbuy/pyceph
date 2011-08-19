from librados cimport rados_ioctx_t, rados_list_ctx_t, rados_xattrs_iter_t

cdef make_ex(int ret, str msg)

cdef class Rados:

    cdef void *cluster
    cdef int   state
    cdef readonly RadosPools pools

    cdef create_pool(self, char *pool_name, int auid, int crush_rule)
    cdef delete_pool(self, char *pool_name)
    cdef list_pools(self)
    cdef open_pool(self, char *pool_name)
    cdef pool_exists(self, char *pool_name)

cdef class RadosPools:

    cdef Rados rados

cdef class RadosPoolsIterator:

    cdef Rados  rados
    cdef object pools_iter

cdef class PoolStats:
    cdef readonly long num_bytes
    cdef readonly long num_kb
    cdef readonly long num_objects
    cdef readonly long num_object_clones
    cdef readonly long num_object_copies
    cdef readonly long num_objects_missing_on_primary
    cdef readonly long num_objects_unfound
    cdef readonly long num_objects_degraded
    cdef readonly long num_rd
    cdef readonly long num_rd_kb
    cdef readonly long num_wr
    cdef readonly long num_wr_kb

cdef class Pool:

    cdef rados_ioctx_t ctx
    cdef str           name

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
    cdef char *key
    cdef int   pos
    cdef int   state
