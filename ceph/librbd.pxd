from libc.stdint cimport int64_t, uint64_t
from librados cimport *

cdef extern from "rbd/librbd.h":

    ctypedef void *rbd_snap_t
    ctypedef void *rbd_image_t

    ctypedef struct rbd_snap_info_t:
        uint64_t id
        uint64_t size
        char     *name

    int RBD_MAX_IMAGE_NAME_SIZE
    int RBD_MAX_BLOCK_NAME_SIZE

    ctypedef struct rbd_image_info_t:
        uint64_t size
        uint64_t obj_size
        uint64_t num_objs
        int      order
        char     block_name_prefix[96]
        int      parent_pool
        char     parent_name[24]

    void rbd_version(int *major, int *minor, int *extra)
    int  rbd_list(rados_ioctx_t io, char *names, size_t *size)
    int rbd_create(rados_ioctx_t io, char *name, uint64_t size, int *order)
    int rbd_remove(rados_ioctx_t io, char *name)
    int rbd_copy(rados_ioctx_t src_io_ctx, char *srcname, rados_ioctx_t dest_io_ctx, char *destname)
    int rbd_rename(rados_ioctx_t src_io_ctx, char *srcname, char *destname)

    int rbd_open(rados_ioctx_t io, char *name, rbd_image_t *image, char *snap_name)
    int rbd_close(rbd_image_t image)
    int rbd_resize(rbd_image_t image, uint64_t size)
    int rbd_stat(rbd_image_t image, rbd_image_info_t *info, size_t infosize)

    int rbd_snap_list(rbd_image_t image, rbd_snap_info_t *snaps, int *max_snaps)
    void rbd_snap_list_end(rbd_snap_info_t *snaps)
    int rbd_snap_create(rbd_image_t image, char *snapname)
    int rbd_snap_remove(rbd_image_t image, char *snapname)
    int rbd_snap_rollback(rbd_image_t image, char *snapname)
    int rbd_snap_set(rbd_image_t image, char *snapname)

    ctypedef void *rbd_completion_t
    ctypedef void (*rbd_callback_t)(rbd_completion_t cb, void *arg)
    ssize_t rbd_read(rbd_image_t image, uint64_t ofs, size_t len, char *buf)
    int64_t rbd_read_iterate(rbd_image_t image, uint64_t ofs, size_t len,
                             int (*cb)(uint64_t, size_t, char *, void *), void *arg)
    ssize_t rbd_write(rbd_image_t image, uint64_t ofs, size_t len, char *buf)
    int rbd_aio_write(rbd_image_t image, uint64_t off, size_t len, char *buf, rbd_completion_t c)
    int rbd_aio_read(rbd_image_t image, uint64_t off, size_t len, char *buf, rbd_completion_t c)
    int rbd_aio_create_completion(void *cb_arg, rbd_callback_t complete_cb, rbd_completion_t *c)
    int rbd_aio_wait_for_complete(rbd_completion_t c)
    ssize_t rbd_aio_get_return_value(rbd_completion_t c)
    void rbd_aio_release(rbd_completion_t c)
