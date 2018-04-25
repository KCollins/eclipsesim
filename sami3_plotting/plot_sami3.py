#!/usr/bin/env python3
import os,glob
import datetime
from collections import OrderedDict

import bz2

import cartopy.crs as ccrs

import matplotlib as mpl
#mpl.use('Agg')
from matplotlib import pyplot as plt
import numpy as np
import scipy.io

import seqp
prep_dir = seqp.gen_lib.prep_output

out_dir = 'output'
prep_dir({0:out_dir},clear=True)

def load_raw_grid():
    nx,ny,nz    = (100,360,100)
    lats    = np.ndarray((nx,ny,nz))*np.nan
    lons    = lats.copy()
    heights = lats.copy()

    grid_fl = 'sami3_raw/sami3_grid.dat.bz2'

    with bz2.BZ2File(grid_fl,'r') as fl:
        result = fl.readlines()

#    (17x100)x360 + 360 = 612360

    for pinx,arr in enumerate([lats,lons]):
        for yi in range(360):
            for zi in range(100):
                grp_start = (17*zi+1)+(yi*1700)+yi+pinx*612359-1
                grp = result[grp_start:grp_start+17]

                vals    = []
                for ln in grp:
                    vals += ln.split()
                vals            = [float(x) for x in vals]
                arr[:,yi,zi]    = vals
                
    # Adjust lons
    tf  = lons > 180.
    lons[tf] = lons[tf] - 360.

    # Heights
    grp_start   = 1224718
    grp         = result[grp_start:grp_start+17]
    vals        = []
    for ln in grp:
        vals += ln.split()
    vals        = [float(x) for x in vals]
    for xx in range(100):
        for yy  in range(360):
            heights[xx,yy,:]    = vals

    grid    = {}
    grid['heights'] = heights
    grid['lats']    = lats
    grid['lons']    = lons
    return grid

def load_ml_grid():
    ml_fl_grid  = 'sami3/grid.mat'
    ml_grid     = scipy.io.loadmat(ml_fl_grid)

    grid            = {}
    grid['heights'] = ml_grid['grid_heights']
    grid['lats']    = ml_grid['grid_lats']
    grid['lons']    = ml_grid['grid_lons']
    return grid

def plot_grid(grids):
    nx  = len(grids)
    ny  = 3

    inx = list(grids.keys())[0]
    ref_heights = grids[inx]['heights']

    marker_sz = 100
    for alt_inx,alt in enumerate(ref_heights[0,0,:]):
        fig     = plt.figure(figsize=(15,10))
        for xinx,(src,grid) in enumerate(grids.items()):
            lats    = grid['lats']
            lons    = grid['lons']
            heights = grid['heights']

            ax_inx  = 1 + xinx
            ax      = fig.add_subplot(ny,nx,ax_inx,projection=ccrs.PlateCarree())
            ax.coastlines()
            xx      = lons[:,:,alt_inx]
            yy      = lats[:,:,alt_inx]
            pcoll   = ax.scatter(xx,yy,c=xx,vmin=-180,vmax=180,s=marker_sz,edgecolor='face',marker='s')
            cbar    = fig.colorbar(pcoll,label='Longitude')
            ax.set_title(src)

            ax_inx  = 3 + xinx
            ax      = fig.add_subplot(ny,nx,ax_inx,projection=ccrs.PlateCarree())
            ax.coastlines()
            xx      = lons[:,:,alt_inx]
            yy      = lats[:,:,alt_inx]
            pcoll   = ax.scatter(xx,yy,c=yy,vmin=-90,vmax=90,s=marker_sz,edgecolor='face',marker='s')
            cbar    = fig.colorbar(pcoll,label='Latitude')
            ax.set_title(src)

            ax_inx  = 5 + xinx
            ax      = fig.add_subplot(ny,nx,ax_inx,projection=ccrs.PlateCarree())
            ax.coastlines()
            xx      = lons[:,:,alt_inx]
            yy      = lats[:,:,alt_inx]
            zz      = heights[:,:,alt_inx]
            pcoll   = ax.scatter(xx,yy,c=zz,vmin=0,vmax=600,s=marker_sz,edgecolor='face',marker='s')
            cbar    = fig.colorbar(pcoll,label='Altitude [km]')
            ax.set_title(src)

        txt     = '{:.1f} km Altitude'.format(alt)
        fig.text(0.5,1,txt,fontdict={'weight':'bold','size':'x-large'},ha='center')
        fig.tight_layout()
        fname   = "{:03d}km_alt.png".format(int(alt))
        fpath   = os.path.join(out_dir,fname)
        print(fpath)
        fig.savefig(fpath,bbox_inches='tight')
        plt.close(fig)

#ml_fls_data = glob.glob(os.path.join('sami3','data_*.mat'))
#lat =   40.
#lon = -100.
#lat_inx     = np.argmin(np.abs(ml_lats[:,0,0]-lat))
#lon_inx     = np.argmin(np.abs(ml_lons[:,0,0]-lon))
#
## 0000: 1600 UT, 0159: 2357 UT (21 August 2017)
#keys = [x for x in range(160)]

if __name__ == '__main__':
    ml_grid         = load_ml_grid()
    raw_grid        = load_raw_grid()

    grids           = OrderedDict()
    grids['ml']     = ml_grid
    grids['raw']    = ml_grid

    plot_grid(grids)
    import ipdb; ipdb.set_trace()