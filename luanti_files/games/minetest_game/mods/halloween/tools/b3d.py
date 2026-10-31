import struct
import numpy as np

def _q(m):  # quaternion w,x,y,z -> 3x3
    w,x,y,z=m
    return np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],
                     [2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],
                     [2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]])

def load(path):
    d=open(path,'rb').read()
    out={'verts':None,'uv':None,'tris':[],'bones':{}}  # bones: name -> {vid:weight}
    def chunks(a,b):
        while a<b:
            tag=d[a:a+4].decode('latin1'); ln=struct.unpack_from('<i',d,a+4)[0]
            yield tag,a+8,a+8+ln; a=a+8+ln
    def cstr(a):
        e=d.index(b'\0',a); return d[a:e].decode('latin1'),e+1
    def node(a,b,M,path):
        name,a=cstr(a)
        pos=struct.unpack_from('<3f',d,a); scl=struct.unpack_from('<3f',d,a+12); rot=struct.unpack_from('<4f',d,a+24); a+=40
        T=np.eye(4); T[:3,:3]=_q(rot)*np.array(scl); T[:3,3]=pos
        M=M@T
        for tag,s,e in chunks(a,b):
            if tag=='MESH':
                s+=4
                for t2,s2,e2 in chunks(s,e):
                    if t2=='VRTS':
                        flags,ns,sz=struct.unpack_from('<3i',d,s2); s2+=12
                        stride=3+(3 if flags&1 else 0)+(4 if flags&2 else 0)+ns*sz
                        n=(e2-s2)//(stride*4)
                        arr=np.frombuffer(d,dtype='<f4',count=n*stride,offset=s2).reshape(n,stride)
                        out['verts']=arr[:,:3].copy()
                        o=3+(3 if flags&1 else 0)+(4 if flags&2 else 0)
                        out['uv']=arr[:,o:o+2].copy()
                    elif t2=='TRIS':
                        n=(e2-s2-4)//12
                        out['tris'].append(np.frombuffer(d,dtype='<i4',count=n*3,offset=s2+4).reshape(n,3))
            elif tag=='BONE':
                n=(e-s)//8
                w={}
                for i in range(n):
                    vid,wt=struct.unpack_from('<if',d,s+i*8); w[vid]=wt
                out['bones'][name]=w
            elif tag=='NODE':
                node(s,e,M,path+[name])
    for tag,s,e in chunks(12,len(d)):
        if tag=='NODE': node(s,e,np.eye(4),[])
    out['tris']=np.concatenate(out['tris'])
    # dominant bone per vertex
    nv=len(out['verts']); best=['']*nv; bw=[0]*nv
    for bn,w in out['bones'].items():
        for v,wt in w.items():
            if wt>bw[v]: bw[v]=wt; best[v]=bn
    out['vbone']=best
    return out
