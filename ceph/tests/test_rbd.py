from ceph.rados import Rados
from ceph.rbd import Pool

class TestRbdPool:

    def test_rbd(self):
        rados = Rados(conf_file='/etc/ceph/ceph.conf')
        rados.connect()

        pool = Pool(rados)
        pool.create('.testdisk', 512 * (1024 * 1024))

        rbd = pool.open('.testdisk')
        # FIXME: do something else here
        rbd.close()

        #pool.rename('.testdisk', '.testdisk2')

        pool.remove('.testdisk2')
