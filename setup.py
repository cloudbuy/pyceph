import os
import sys

sys.path.append(os.path.join(os.path.dirname(__file__), '.pyrex'))

from setuptools import setup, Extension
from distutils.cmd import Command
from distutils.command.clean import clean as _clean
from Cython.Distutils import build_ext

setup (
    name    = 'ceph',
    version = '0.1',
    description = 'Bindings for the Ceph libraries written using Cython',
    long_description = '',
    author = 'Damien Churchill',
    author_email = 'damoxc@gmail.com',
    license = 'GPLv2',
    url = '',
    cmdclass = {
        'build_ext': build_ext,
    },
    zip_safe = False,
    ext_modules = [
        Extension('ceph.rados', ['ceph/rados.pyx'], libraries = ['rados']),
        Extension('ceph.rbd', ['ceph/rbd.pyx'], libraries = ['rados', 'rbd'])
    ]
)
