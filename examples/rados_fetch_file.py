from ceph.rados import Rados

rados = Rados(conf_file='/etc/ceph/ceph.conf')

pool = rados.pools['example']
for line in pool.open('foo'):
    print line

pool.close()
rados.shutdown()
