import time

from cpython.mem cimport PyMem_Malloc, PyMem_Free
from libc.string cimport strncpy, strlen, strcspn
from libc.stdio cimport printf

from librados cimport *
from libc.errno cimport ENOENT, EPERM, EIO, ENOSPC, EEXIST, ENODATA

cdef uint64_t ANONYMOUS_AUID = 0xffffffffffffffff
cdef int ADMIN_AUID = 0

# File-object States
cdef int FO_CLOSED  = 1
cdef int FO_OPEN    = 2
cdef int FO_EXISTS  = 4
cdef int FO_REMOVED = 8

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

    def __del__(self):
        self.shutdown()

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

    def open_pool(self, char *pool_name):
        cdef rados_ioctx_t ctx = NULL
        cdef int ret
        ret = rados_ioctx_create(self.cluster, pool_name, &ctx)
        if ret < 0:
            raise make_ex(ret, "error opening pool '%s'" % pool_name)

        pool = Pool(pool_name)
        pool.ctx = ctx
        return pool

    def pool_exists(self, char *pool_name):
        cdef int ret
        ret = rados_pool_lookup(self.cluster, pool_name)
        if ret >= 0:
            return True
        elif ret == -ENOENT:
            return False
        else:
            raise make_ex(ret, "error looking up pool '%s'" % pool_name)

    def shutdown(self):
        rados_shutdown(self.cluster)

cdef class PoolStats:

    def __cinit__(self):
        pass

cdef class Pool:

    property auid:
        """
        Get or set the owner of the pool.
        """
        def __get__(self):
            cdef int ret
            cdef uint64_t auid = 0
            ret = rados_ioctx_pool_get_auid(self.ctx, &auid)
            if ret < 0:
                raise make_ex(ret, "error getting auid of '%s'" % (self.name))
            return auid

        def __set__(self, auid):
            cdef int ret
            ret = rados_ioctx_pool_set_auid(self.ctx, auid)
            if ret < 0:
                raise make_ex(ret, "error changing auid of '%s' to %lld" % (self.name, auid))

    property stats:
        def __get__(self):
            cdef int               ret
            cdef rados_pool_stat_t stats
            cdef PoolStats         pool_stats

            ret = rados_ioctx_pool_stat(self.ctx, &stats)
            if ret < 0:
                raise make_ex(ret, "Pool.stats(%s): stats failed" % self.name)

            pool_stats = PoolStats()
            pool_stats.num_bytes                      = stats.num_bytes
            pool_stats.num_kb                         = stats.num_kb
            pool_stats.num_objects                    = stats.num_objects
            pool_stats.num_object_clones              = stats.num_object_clones
            pool_stats.num_object_copies              = stats.num_object_copies
            pool_stats.num_objects_missing_on_primary = stats.num_objects_missing_on_primary
            pool_stats.num_objects_unfound            = stats.num_objects_unfound
            pool_stats.num_objects_degraded           = stats.num_objects_degraded
            pool_stats.num_rd                         = stats.num_rd
            pool_stats.num_rd_kb                      = stats.num_rd_kb
            pool_stats.num_wr                         = stats.num_wr
            pool_stats.num_wr_kb                      = stats.num_wr_kb
            return pool_stats

    def __init__(self, pool_name):
        self.name = pool_name

    def __del__(self):
        self.close()

    def __iter__(self):
        return ObjectIterator(self)

    def __repr__(self):
        return '<ceph.rados.Pool(%r)' % (self.name)

    def append(self, key, data):
        cdef int ret
        cdef char *buf
        buf = data

        ret = rados_append(self.ctx, key, buf, strlen(buf))
        if ret < 0:
            raise make_ex(ret, "Pool.write(%s): failed to write %s" % (self.name, key))

    def close(self):
        rados_ioctx_destroy(self.ctx)

    def list(self):
        return iter(self)

    def open(self, key):
        obj = Object()
        obj.key = key
        obj.pool = self
        return obj

    cdef char *_read(self, char *key, int length, int offset):
        cdef int ret
        cdef char *buf

        buf = <char *>PyMem_Malloc(length + 1)
        ret = rados_read(self.ctx, key, buf, length, offset)
        if ret < 0:
            raise make_ex(ret, "Pool.read(%s): failed to read %s" % (self.name, key))

        if ret == 0:
            return NULL

        return buf

    def read(self, key, length=1024, offset=0):
        cdef char *buf
        buf = self._read(key, length, offset)
        buf[length + 1] = '\0'
        return buf

    def remove(self, key):
        cdef int ret
        ret = rados_remove(self.ctx, key)
        if ret < 0:
            raise make_ex(ret, "Pool.remove(%s): failed to remove %s" % (self.name, key))

    def stat(self, key):
        cdef uint64_t psize = 0, pmtime = 0
        cdef int ret

        ret = rados_stat(self.ctx, key, &psize, <time_t *>(&pmtime))
        if ret < 0:
            raise make_ex(ret, "Failed to stat %r" % key)
        return psize, time.localtime(pmtime)

    def truncate(self, key, size):
        cdef int ret

        ret = rados_trunc(self.ctx, key, size)
        if ret < 0:
            raise make_ex(ret, "Pool.truncate(%s): failed to truncate %s" % (self.name, key))

    def write(self, key, data, offset=0):
        cdef int ret, length
        cdef char *buf
        buf = data
        length = strlen(buf)

        ret = rados_write(self.ctx, key, buf, length, offset)
        if ret == length:
            return ret
        elif ret < 0:
            raise make_ex(ret, "Pool.write(%s): failed to write %s" % (self.name, key))
        elif ret < length:
            raise IncompleteWriteError("Wrote only %ld out of %ld bytes" % (ret, length))
        else:
            raise make_ex(ret, "Pool.write(%s): logic error: rados_write \
returned %d, but %d was the maximum number of bytes it could have \
written." % (self.name, ret, length))

    def write_full(self, key, data, offset=0):
        cdef int ret
        cdef char *buf
        buf = data

        ret = rados_write_full(self.ctx, key, buf, strlen(buf), offset)
        if ret == 0:
            return ret
        else:
            raise make_ex(ret, "Pool.write_full(%s): failed to write_full %s" % (self.name, key))

cdef class ObjectIterator:

    def __init__(self, Pool pool):
        cdef int ret
        self.pool = pool

        ret = rados_objects_list_open(self.pool.ctx, &self.ctx)
        if ret < 0:
            raise make_ex(ret, "error iterating over the objects in %r" % self.pool)

    def __del__(self):
        rados_objects_list_close(self.ctx)

    def __iter__(self):
        return self

    def __next__(self):
        cdef char *key = NULL
        cdef int ret

        ret = rados_objects_list_next(self.ctx, <const_char_pp>&key)
        if ret < 0:
            raise StopIteration

        return self.pool.open(key)

cdef class ObjectXAttrs:

    def __init__(self, Object obj):
        self.obj = obj

    def __delitem__(self, key):
        cdef int ret

        ret = rados_rmxattr(self.obj.pool.ctx, self.obj.key, key)
        if ret < 0:
            raise make_ex(ret, "Failed to delete key %r xattr %r" % (self.obj.key, key))

    def __getitem__(self, key):
        cdef int ret
        cdef char buf[4096]

        ret = rados_getxattr(self.obj.pool.ctx, self.obj.key, key, buf, 4066)
        if ret < 0:
            raise make_ex(ret, "Failed to get xattr %r" % key)

        buf[ret] = '\0'

        return buf

    def __setitem__(self, key, value):
        cdef int ret
        cdef char *k = key, *v = value
        ret = rados_setxattr(self.obj.pool.ctx, self.obj.key, k, v, strlen(v))
        if ret < 0:
            raise make_ex(ret, "Failed to set xattr %r" % key)

    def __iter__(self):
        return ObjectXAttrsIterator(self.obj)

cdef class ObjectXAttrsIterator:

    def __init__(self, Object obj):
        cdef int ret
        self.obj = obj
        ret = rados_getxattrs(obj.pool.ctx, obj.key, &self.ctx)
        if ret != 0:
            raise make_ex(ret, "Failed to get rados xattrs for %r" % obj)

    def __del__(self):
        rados_getxattrs_end(self.ctx)

    def __iter__(self):
        return self

    def __next__(self):
        cdef char *name = NULL, *value = NULL
        cdef int ret
        cdef size_t length = 0

        ret = rados_getxattrs_next(self.ctx, <const_char_pp>&name, <const_char_pp>&value, &length)
        if ret != 0:
            raise make_ex(ret, "error iterating over the extended attributes in %r" % self.obj)

        if length == 0:
            raise StopIteration

        value[length] = '\0'
        return name, value

cdef class Object:
    """
    Represents an object stored in a RADOS pool, providing a file-like
    interface to it.
    """

    property xattrs:
        def __get__(self):
            return ObjectXAttrs(self)

    def __cinit__(self):
        self.pos = 0
        self.state = FO_OPEN

    def __del__(self):
        self.close()

    def __iter__(self):
        return self

    def __next__(self):
        line = self.readline()
        if not line:
            raise StopIteration
        return line

    def close(self):
        self.state = FO_CLOSED

    def fileno(self):
        raise NotImplementedError

    def flush(self):
        raise NotImplementedError

    def read(self, size=1024):
        return self.pool.read(self.key, size, self.pos)

    def readline(self, size=1024):
        cdef char *buf, *line
        cdef int pos
        buf = self.pool._read(self.key, size, self.pos)
        if buf == NULL:
            PyMem_Free(buf)
            return ''

        pos = strcspn(buf, "\n")

        # Allocate enough space for the line, plus newline, plus null
        line = <char *>PyMem_Malloc(pos + 1)
        strncpy(line, buf, pos + 1)
        line[pos + 1] = '\0'

        self.pos += pos + 1

        PyMem_Free(buf)
        return line

    def readlines(self, sizehint=None):
        raise NotImplementedError

    def seek(self, offset, whence=None):
        raise NotImplementedError

    def stat(self):
        return self.pool.stat(self.key)

    def tell(self):
        return self.pos

    def truncate(self, size=None):
        cdef int s
        s = size if size else self.pos
        self.pool.truncate(self.key, s)

    def write(self, value):
        self.pool.write(self.key, value, self.pos)

    def writelines(self, lines):
        for line in lines:
            self.write(line)
