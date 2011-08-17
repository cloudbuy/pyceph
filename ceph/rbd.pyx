from librados cimport *
from librbd cimport *

from cpython.mem cimport PyMem_Malloc, PyMem_Free
from libc.errno cimport ERANGE
from libc.string cimport strncpy, strlen, memcpy
from libc.stdio cimport printf

from rados cimport Rados, make_ex

cdef int _major = 0, _minor = 0, _extra = 0
rbd_version(&_major, &_minor, &_extra)
version_info = (_major, _minor, _extra)

cdef class Pool:

    cdef rados_ioctx_t ctx

    def __init__(self, Rados rados, bytes pool_name=b'rbd'):
        cdef int ret

        if not rados.pool_exists(pool_name):
            raise Exception('No pool exists by that name')

        ret = rados_ioctx_create(rados.cluster, pool_name, &self.ctx)
        if ret != 0:
            make_ex(ret, 'Failed to open pool')

    def __del__(self):
        self.close()

    def close(self):
        rados_ioctx_destroy(self.ctx)

    def copy(self, image_name, dest_name, Pool dest_pool=None):
        cdef int ret

        if dest_pool is None:
            dest_pool = self

        ret = rbd_copy(self.ctx, image_name, dest_pool.ctx, dest_name)
        if ret != 0:
            make_ex(ret, 'error whilst copying the rbd')

    def create(self, image_name, size, order=None):
        cdef int ret, _order
        if order is None:
            _order = 0
        else:
            _order = order
        ret = rbd_create(self.ctx, image_name, size, &_order)
        if ret != 0:
            make_ex(ret, 'error creating new rbd')

    def list(self):
        cdef int ret, length, total = 0
        cdef char buf[1024], *name
        cdef size_t size = 1024

        ret = rbd_list(self.ctx, buf, &size)
        if ret < 0:
            raise make_ex(ret, "error getting rbd list")

        names = []
        while ret > 0:
            length = strlen(&buf[total]) + 1

            name = <char *>PyMem_Malloc(length)
            strncpy(name, &buf[total], length)
            names.append(name)
            total += length
            ret -= 1

        return names

    def open(self, image_name, snap_name=None):
        return Rbd(self, image_name, snap_name)

    def remove(self, image_name):
        cdef int ret
        ret = rbd_remove(self.ctx, image_name)
        if ret != 0:
            raise make_ex(ret, "error removing rbd")

    def rename(self, image_name, dest_name):
        cdef int ret
        ret = rbd_rename(self.ctx, image_name, dest_name)
        if ret != 0:
            raise make_ex(ret, "error removing rbd")

    def resize(self, image_name, new_size):
        rbd = self.open(image_name)
        return rbd.resize(new_size)

    def stat(self, image_name):
        return self.open(image_name).stat()

cdef class RbdStat:

    cdef rbd_image_info_t info

    property size:
        def __get__(self):
            return self.info.size

    property obj_size:
        def __get__(self):
            return self.info.obj_size

    property num_objs:
        def __get__(self):
            return self.info.num_objs

    property order:
        def __get__(self):
            return self.info.order

    property block_name_prefix:
        def __get__(self):
            return self.info.block_name_prefix

    property parent_pool:
        def __get__(self):
            return self.info.parent_pool

    property parent_name:
        def __get__(self):
            return self.info.parent_name

cdef class RbdSnapshot:

    cdef readonly uint64_t id
    cdef readonly uint64_t size
    cdef readonly char    *name

    def __cinit__(self):
        self.name = <char *>PyMem_Malloc(128)

    def __dealloc__(self):
        PyMem_Free(self.name)

    def __str__(self):
        return self.name

cdef class RbdSnapshots:

    cdef Rbd rbd
    cdef rbd_image_t image

    def create(self, snap_name):
        cdef int ret
        ret = rbd_snap_create(self.image, snap_name)
        if ret < 0:
            raise make_ex(ret, "error calling rbd_snap_create")

    def list(self):
        cdef rbd_snap_info_t *snaps
        cdef int ret, max_snaps = 10
        cdef RbdSnapshot snapshot

        while True:
            snaps = <rbd_snap_info_t *>PyMem_Malloc(sizeof(snaps[0]) * max_snaps)
            ret = rbd_snap_list(self.image, snaps, &max_snaps)
            if ret >= 0:
                max_snaps = ret
                break
            elif ret != -ERANGE:
                raise make_ex(ret, "error calling rbd_snap_list")

            max_snaps = max_snaps * 2

        snapshots = []
        for i in range(max_snaps):
            snapshot = RbdSnapshot()
            strncpy(snapshot.name, snaps[i].name, 128)
            snapshot.size = snaps[i].size
            snapshot.id = snaps[i].id
            snapshots.append(snapshot)

        rbd_snap_list_end(snaps)

        return snapshots

    def remove(self, snap_name):
        cdef int ret
        ret = rbd_snap_remove(self.image, snap_name)
        if ret < 0:
            raise make_ex(ret, "error calling rbd_snap_remove")

    def rollback(self, snap_name):
        cdef int ret
        ret = rbd_snap_rollback(self.image, snap_name)
        if ret < 0:
            raise make_ex(ret, "error calling rbd_snap_remove")

    def set(self, snap_name):
        cdef int ret
        ret = rbd_snap_set(self.image, snap_name)
        if ret < 0:
            raise make_ex(ret, "error calling rbd_snap_set")

    def __delitem__(self, key):
        self.remove(key)

    def __getitem__(self, key):
        snapshots = [s for s in self.list() if s.name == key]
        if snapshots:
            return snapshots[0]
        else:
            raise KeyError("no snapshot by that name")

    def __str__(self):
        return str([str(s) for s in self.list()])

cdef class Rbd:

    cdef Pool pool
    cdef RbdSnapshots _snapshots
    cdef rados_ioctx_t ctx
    cdef rbd_image_t image
    cdef bint closed

    property snapshots:
        def __get__(self):
            return self._snapshots

    def __init__(self, Pool pool, image_name, snap_name=None):
        cdef int ret
        cdef char *snap = NULL

        self.closed = True

        self.pool = pool
        self.ctx = pool.ctx
        if snap_name != None:
            snap = snap_name

        ret = rbd_open(self.ctx, image_name, &self.image, snap)
        if ret != 0:
            raise make_ex(ret, "error opening rbd")

        self._snapshots = RbdSnapshots()
        self._snapshots.rbd = self
        self._snapshots.image = self.image

        self.closed = False

    def __del__(self):
        self.close()

    def close(self):
        cdef int ret
        ret = rbd_close(self.image)
        if ret != 0:
            raise make_ex(ret, "error closing rbd")
        self.closed = True

    def resize(self, new_size):
        cdef int ret
        ret = rbd_resize(self.image, new_size)
        if ret != 0:
            raise make_ex(ret, "error resizing rbd")

    def stat(self):
        cdef int ret
        cdef rbd_image_info_t info

        ret = rbd_stat(self.image, &info, sizeof(info))
        if ret != 0:
            raise make_ex(ret, "error getting rbd information")

        rbd_stats = RbdStat()
        rbd_stats.info = info

        return rbd_stats
