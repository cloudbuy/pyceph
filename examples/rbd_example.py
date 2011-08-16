from ceph.rados import Rados
from ceph.rbd import Pool

rados = Rados(conf_file='/etc/ceph/ceph.conf')
rados.connect()

pool = Pool(rados)
rbd = pool.open('example-disk')
rbd.snapshots.create('20110815T1626Z')
print rbd.snapshots
rbd.close()
pool.close()
rados.shutdown()
