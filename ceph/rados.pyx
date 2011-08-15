from cpython.mem cimport PyMem_Malloc, PyMem_Free
from libc.string cimport strncpy, strlen
from libc.stdio cimport printf

from librados cimport *
from libc.errno cimport ENOENT, EPERM, EIO, ENOSPC, EEXIST, ENODATA

cdef uint64_t ANONYMOUS_AUID = 0xffffffffffffffff
cdef int ADMIN_AUID = 0

cdef int _major = 0, _minor = 0, _extra = 0
rados_version(&_major, &_minor, &_extra)
version_info = (_major, _minor, _extra)

class Error(Exception):
    def __init__(self, code):
        self.code = code
    def __repr__(self):
        return "rados.Error(code=%d)" % self.code

class PermissionError(Exception):
    pass

class ObjectNotFound(Exception):
    pass

class NoData(Exception):
    pass

class ObjectExists(Exception):
    pass

class IOError(Exception):
    pass

class NoSpace(Exception):
    pass

class IncompleteWriteError(Exception):
    pass

class RadosStateError(Exception):
    pass

class IoctxStateError(Exception):
    pass

class ObjectStateError(Exception):
    pass

cdef make_ex(int ret, str msg):
    ret = abs(ret)
    if ret == EPERM:
        return PermissionError(msg)
    elif ret == ENOENT:
        return ObjectNotFound(msg)
    elif ret == EIO:
        return IOError(msg)
    elif ret == ENOSPC:
        return NoSpace(msg)
    elif ret == EEXIST:
        return ObjectExists(msg)
    elif ret == ENODATA:
        return NoData(msg)
    else:
        return Error(msg + (": error code %d" % ret))

cdef class Rados:

    def __init__(self, bytes conf_file=None, monitors=None, rados_id=None):
        cdef char *rid = '', *p
        cdef int ret
        if rados_id is not None:
            rid = rados_id
        ret = rados_create(&self.cluster, rid)
        if ret != 0:
            raise Exception("rados_create failed with error code: %d" % ret)

        if conf_file:
            p = conf_file
            ret = rados_conf_read_file(self.cluster, p)
            if ret != 0:
                raise make_ex(ret, "error calling conf_read_file")


    def conf_read_file(self, bytes path=None):
        cdef int ret
        cdef char *p
        p = path
        ret = rados_conf_read_file(self.cluster, p)
        if ret != 0:
            raise make_ex(ret, "error calling conf_read_file")

    def connect(self):
        cdef int ret
        ret = rados_connect(self.cluster)
        if ret != 0:
            raise make_ex(ret, "error calling connect")

    def create_pool(self, pool_name, auid=None, crush_rule=None):
        cdef int ret
        if auid is None:
            if crush_rule is None:
                ret = rados_pool_create(self.cluster, pool_name)
            else:
                ret = rados_pool_create_with_all(self.cluster, pool_name, auid, crush_rule)
        elif crush_rule is None:
            ret = rados_pool_create_with_auid(self.cluster, pool_name, auid)
        else:
            ret = rados_pool_create_with_crush_rule(self.cluster, pool_name, crush_rule)

        if ret < 0:
            raise make_ex(ret, "error creating pool '%s'" % pool_name)

    def delete_pool(self, pool_name):
        cdef int ret
        ret = rados_pool_delete(self.cluster, pool_name)
        if ret < 0:
            raise make_ex(ret, "error deleting pool '%s'" % pool_name)

    def list_pools(self):
        cdef int ret, length, total = 0
        cdef char buf[1024], *name

        ret = rados_pool_list(self.cluster, buf, 1024)

        if ret < 0:
            raise make_ex(ret, "error getting pools list")

        pools = []
        while total < ret:
            length = strlen(&buf[total]) + 1
            if length < 2: # Use 2 because 1 == '\0'
                break

            name = <char *>PyMem_Malloc(length)
            strncpy(name, &buf[total], length)
            pools.append(name)
            total += length

        return pools

    def pool_exists(self, char *pool_name):
        cdef void *pool
        cdef int ret
        ret = rados_pool_lookup(self.cluster, pool_name)
        if ret >= 0:
            return True
        elif ret == -ENOENT:
            return False
        else:
            raise make_ex(ret, "error looking up pool '%s'" % pool_name)
