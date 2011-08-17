from ceph.rados import Rados

class TestRadosPools:

    def test_pools(self):
        rados = Rados(conf_file='/etc/ceph/ceph.conf')
        rados.connect()
        assert not rados.pool_exists('.testpool')
        rados.create_pool('.testpool')
        assert rados.pool_exists('.testpool')
        rados.delete_pool('.testpool')
        assert not rados.pool_exists('.testpool')
        rados.shutdown()
