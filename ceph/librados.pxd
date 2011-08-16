from libc.stdint cimport uint8_t, uint64_t

cdef extern from *:
    ctypedef uint8_t  __u8
    ctypedef char* const_char_pp "const char **"

cdef extern from "time.h":
    ctypedef void time_t

cdef extern from "rados/librados.h":

    struct CephContext

    ctypedef void *rados_t
    ctypedef void *rados_ioctx_t
    ctypedef void *rados_list_ctx_t
    ctypedef uint64_t rados_snap_t
    ctypedef void *rados_xattrs_iter_t

    struct rados_pool_stat_t:
        uint64_t num_bytes
        uint64_t num_kb
        uint64_t num_objects
        uint64_t num_object_clones
        uint64_t num_object_copies
        uint64_t num_objects_missing_on_primary
        uint64_t num_objects_unfound
        uint64_t num_objects_degraded
        uint64_t num_rd, num_rd_kb,num_wr, num_wr_kb

    struct rados_cluster_stat_t:
        uint64_t kb, kb_used, kb_avail
        uint64_t num_objects

    void rados_version(int *major, int *minor, int *extra)

    # initialization
    int rados_create(rados_t *cluster, char *id)

    # initialize rados with an existing configuration.
    int rados_create_with_context(rados_t *cluster, CephContext *cct_)

    # Connect to the cluster
    int rados_connect(rados_t cluster)

    # destroy the cluster instance
    void rados_shutdown(rados_t cluster)

# Config
    int rados_conf_read_file(rados_t cluster, char *path)

    void rados_conf_parse_argv(rados_t cluster, int argc, char **argv)

    int rados_conf_set(rados_t cluster, char *option, char *value)

    int rados_conf_get(rados_t cluster, char *option, char *buf, size_t len)

    int rados_cluster_stat(rados_t cluster, rados_cluster_stat_t *result)

# Pools

    int rados_pool_list(rados_t cluster, char *buf, size_t len)

    int rados_ioctx_create(rados_t cluster, char *pool_name, rados_ioctx_t *ioctx)
    void rados_ioctx_destroy(rados_ioctx_t io)

    int rados_ioctx_pool_stat(rados_ioctx_t io, rados_pool_stat_t *stats)

    int rados_pool_lookup(rados_t cluster, char *pool_name)
    int rados_pool_create(rados_t cluster, char *pool_name)
    int rados_pool_create_with_auid(rados_t cluster, char *pool_name, uint64_t auid)
    int rados_pool_create_with_crush_rule(rados_t cluster, char *pool_name,
                                          __u8 crush_rule)
    int rados_pool_create_with_all(rados_t cluster, char *pool_name, uint64_t auid,
                                   __u8 crush_rule)
    int rados_pool_delete(rados_t cluster, char *pool_name)
    int rados_ioctx_pool_set_auid(rados_ioctx_t io, uint64_t auid)
    int rados_ioctx_pool_get_auid(rados_ioctx_t io, uint64_t *auid)

    void rados_ioctx_locator_set_key(rados_ioctx_t io, char *key)
    int rados_ioctx_get_id(rados_ioctx_t io)

# Objects
    int rados_objects_list_open(rados_ioctx_t io, rados_list_ctx_t *ctx)
    int rados_objects_list_next(rados_list_ctx_t ctx, const_char_pp entry)
    void rados_objects_list_close(rados_list_ctx_t ctx)

# Snapshots
    int rados_ioctx_snap_create(rados_ioctx_t io, char *snapname)
    int rados_ioctx_snap_remove(rados_ioctx_t io, char *snapname)
    int rados_rollback(rados_ioctx_t io, char *oid,
                       char *snapname)
    void rados_ioctx_snap_set_read(rados_ioctx_t io, rados_snap_t snap)
    int rados_ioctx_selfmanaged_snap_create(rados_ioctx_t io, uint64_t *snapid)
    int rados_ioctx_selfmanaged_snap_remove(rados_ioctx_t io, uint64_t snapid)
    int rados_ioctx_selfmanaged_snap_rollback(rados_ioctx_t io, char *oid, uint64_t snapid)
    int rados_ioctx_selfmanaged_snap_set_write_ctx(rados_ioctx_t io, rados_snap_t seq, rados_snap_t *snaps, int num_snaps)

    int rados_ioctx_snap_list(rados_ioctx_t io, rados_snap_t *snaps, int maxlen)
    int rados_ioctx_snap_lookup(rados_ioctx_t io, char *name, rados_snap_t *id)
    int rados_ioctx_snap_get_name(rados_ioctx_t io, rados_snap_t id, char *name, int maxlen)
    int rados_ioctx_snap_get_stamp(rados_ioctx_t io, rados_snap_t id, time_t *t)

# Sync I/O
    uint64_t rados_get_last_version(rados_ioctx_t io)

    int rados_write(rados_ioctx_t io, char *oid, char *buf, size_t len, uint64_t off)
    int rados_write_full(rados_ioctx_t io, char *oid, char *buf, size_t len, uint64_t off)
    int rados_clone_range(rados_ioctx_t io, char *dst, uint64_t dst_off,
                          char *src, uint64_t src_off, size_t len)
    int rados_append(rados_ioctx_t io, char *oid, char *buf, size_t len)
    int rados_read(rados_ioctx_t io, char *oid, char *buf, size_t len, uint64_t off)
    int rados_remove(rados_ioctx_t io, char *oid)
    int rados_trunc(rados_ioctx_t io, char *oid, uint64_t size)

# Attrs
    int rados_getxattr(rados_ioctx_t io, char *o, char *name, char *buf, size_t len)
    int rados_setxattr(rados_ioctx_t io, char *o, char *name, char *buf, size_t len)
    int rados_rmxattr(rados_ioctx_t io, char *o, char *name)

    int rados_getxattrs(rados_ioctx_t io, char *oid, rados_xattrs_iter_t *iter)
    int rados_getxattrs_next(rados_xattrs_iter_t iter, char **name,
                             char **val, size_t *len)
    void rados_getxattrs_end(rados_xattrs_iter_t iter)

# Misc
    int rados_stat(rados_ioctx_t io, char *o, uint64_t *psize, time_t *pmtime)
    int rados_tmap_update(rados_ioctx_t io, char *o, char *cmdbuf, size_t cmdbuflen)
    int rados_exec(rados_ioctx_t io, char *oid, char *cls, char *method,
                   char *in_buf, size_t in_len, char *buf, size_t out_len)

# Async I/O
    ctypedef void *rados_completion_t
    ctypedef void (*rados_callback_t)(rados_completion_t cb, void *arg)

    int rados_aio_create_completion(void *cb_arg, rados_callback_t cb_complete, rados_callback_t cb_safe,
                                    rados_completion_t *pc)
    int rados_aio_wait_for_complete(rados_completion_t c)
    int rados_aio_wait_for_safe(rados_completion_t c)
    int rados_aio_is_complete(rados_completion_t c)
    int rados_aio_is_safe(rados_completion_t c)
    int rados_aio_get_return_value(rados_completion_t c)
    uint64_t rados_aio_get_obj_ver(rados_completion_t c)
    void rados_aio_release(rados_completion_t c)
    int rados_aio_write(rados_ioctx_t io, char *oid,
                        rados_completion_t completion,
                        char *buf, size_t len, uint64_t off)
    int rados_aio_append(rados_ioctx_t io, char *oid,
                         rados_completion_t completion,
                         char *buf, size_t len)
    int rados_aio_write_full(rados_ioctx_t io, char *oid,
                             rados_completion_t completion,
                             char *buf, size_t len)
    int rados_aio_read(rados_ioctx_t io, char *oid,
                       rados_completion_t completion,
                       char *buf, size_t len, uint64_t off)

    int rados_aio_flush(rados_ioctx_t io)

# Watch/Notify
    ctypedef void (*rados_watchcb_t)(uint8_t opcode, uint64_t ver, void *arg)
    int rados_watch(rados_ioctx_t io, char *o, uint64_t ver, uint64_t *handle,
                    rados_watchcb_t watchcb, void *arg)
    int rados_unwatch(rados_ioctx_t io, char *o, uint64_t handle)
    int rados_notify(rados_ioctx_t io, char *o, uint64_t ver, char *buf, int buf_len)
