from ceph.rados import Rados

rados = Rados(conf_file='/etc/ceph/ceph.conf')

if 'example' not in rados.pools:
    raise Exception('Missing pool')

pool = rados.pools['example']
for line in pool.open('foo'):
    print line

# not really required as it's the end of the script
pool.close()
rados.shutdown()
