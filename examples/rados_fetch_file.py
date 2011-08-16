from ceph.rados import Rados

rados = Rados(conf_file='/etc/ceph/ceph.conf')
rados.connect()

pool = rados.open_pool('example')
for line in pool.open('foo'):
    print line

pool.close()
rados.shutdown()
