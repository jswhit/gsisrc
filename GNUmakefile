#
# Makefile for ESMA components.
#
# REVISION HISTORY:
#
# 3mar2004  Zaslavsky  Initial imlementation.
# 20Oct2004  da Silva  Standardization
# 16Mar2007  Kokron    Remove default optimization; Add LOOP_VECT 
#

# Make sure ESMADIR is defined
# ----------------------------
ifndef ESMADIR
       ESMADIR := $(PWD)/../../..
endif

# Compilation rules, flags, etc
# -----------------------------
  include $(ESMADIR)/Config/ESMA_base.mk  # Generic stuff
  include $(ESMADIR)/Config/ESMA_arch.mk  # System dependencies
  include $(ESMADIR)/Config/GMAO_base.mk  # System dependencies

#                  ---------------------
#                  Standard ESMA Targets
#                  ---------------------


THIS = $(shell basename `pwd`)
LIB  = lib$(THIS).a
BIN  = prepbykx.x

#                  --------------------------------
#                   Recurse Make in Sub-directories
#                  --------------------------------

ALLDIRS = mksi

SUBDIRS = $(wildcard $(ALLDIRS))

TARGETS = esma_install esma_clean esma_distclean esma_doc \
          install clean distclean doc 

.PHONY: install local_install install_lib install_inc install_bin install_etc

export ESMADIR BASEDIR ARCH SITE

$(TARGETS): 
	@ t=$@; argv="$(SUBDIRS)" ;\
	  for d in $$argv; do                    \
	    ( cd $$d                            ;\
	      echo ""; echo Making $$t in `pwd`          ;\
	      $(MAKE) -e $$t ) \
	  done
	$(MAKE) local_$@

#                  ----------------------
#                   User Defined Targets
#                  ----------------------

ifeq ( $(wildcard $(LIB_MAPL_BASE)),$(null))
   HAVE_ESMF  =
   INC_ESMF   =
   INC_GEOS   =
   GSIGC_SRCS =
   BIN       += gsi.x
else
   HAVE_ESMF = -DHAVE_ESMF
   INC_GEOS  = $(INC_MAPL_BASE) $(INC_GEOS_SHARED)
   GSIGC_SRCS = GSI_GridCompMod.F90
endif
LIB_GMAO = $(LIB_TRANSF) $(LIB_HERMES)  $(LIB_GFIO) $(LIB_MPEU)
LIB_GMAO = 

# To deactivate GEOS_PERT-related routines
# ----------------------------------------
GEOS_PERT = -DGEOS_PERT
GEOS_PERT =
INC_FVGCM =
LIB_FVGCM =

RSRC =	gmao_airs_bufr.tbl		\
	gmao_global_blacklist.txt	\
	gmao_global_convinfo.txt	\
	gmao_global_ozinfo.txt		\
	gmao_global_pcpinfo.txt		\
	gmao_global_satinfo.txt		\
	gsi_fdda.rc.tmpl 		\
	gsi.rc.tmpl			\
	gsi_sens.rc.tmpl		\
	obs.rc.tmpl

local_esma_install local_install:
	$(MAKE) install_lib
	$(MAKE) install_inc
	$(MAKE) install_bin
	$(MAKE) install_etc

install_lib: $(ESMALIB) $(LIB)
	@ echo "-- $@: $(LIB) --> $(ESMALIB)/ --"
	$(CP) $(LIB)     $(ESMALIB)/

install_inc: $(ESMAINC)/$(THIS)
	@ echo "-- $@: *.mod --> $(ESMAINC)/ --"
	$(CP) *.mod     $(ESMAINC)/$(THIS)

install_bin: $(ESMABIN) $(BIN) analyzer gsidiags
	@ echo "-- $@: $(BIN) --> $(ESMABIN)/ --"
	$(CP) $(BIN)     $(ESMABIN)/
	$(SED) -e "s^@DASPERL^$(PERL)^" < analyzer > $(ESMABIN)/analyzer
	$(SED) -e "s^@DASPERL^$(PERL)^" < gsidiags > $(ESMABIN)/gsidiags
	chmod 755 $(ESMABIN)/analyzer
	chmod 755 $(ESMABIN)/gsidiags

install_etc: $(ESMAETC) $(RSRC)
	@ echo "-- $@: $(RSRC) --> $(ESMAETC)/ --"
	@ for f in $(RSRC); do \
	    ( case $$f in \
	      *.sample)		F=`basename $$f .sample` ;;\
	      *.txt)		F=`basename $$f .txt`.rc ;;\
	      *)		F=$$f			 ;;\
	      esac ;\
	      echo "$(CP) $$f     $(ESMAETC)/$$F" ;\
	      $(CP) $$f $(ESMAETC)/$$F )\
	  done

$(ESMALIB) $(ESMABIN) $(ESMAINC)/$(THIS) $(ESMAETC):
	@ echo "$@: making directory $@ ..."
	$(MKDIR) $@

local_esma_clean local_clean:
	$(RM) *~ *.[aox] *.[Mm][Oo][Dd]

local_esma_distclean local_distclean:
	$(RM) *~ *.[aoxd] *.[Mm][Oo][Dd]

local_esma_doc local_doc:
	@echo "Target $@ not implemented yet in `pwd`"


esma_help help:
	@echo "Standard ESMA targets:"
	@echo "% make esma_install    (builds and install under ESMADIR)"
	@echo "% make esma_clean      (removes deliverables: *.[aox], etc)"
	@echo "% make esma_distclean  (leaves in the same state as cvs co)"
	@echo "% make esma_doc        (generates PDF, installs under ESMADIR)"
	@echo "% make esma_help       (this message)"
	@echo "Environment:"
	@echo "      ESMADIR = $(ESMADIR)"
	@echo "      BASEDIR = $(BASEDIR)"
	@echo "         ARCH = $(ARCH)"
	@echo "         SITE = $(SITE)"
	@echo "        FREAL = $(FREAL)"

show_fflags:
	@echo "FFLAGS          = $(FFLAGS)"
	@echo "F90FLAGS        = $(F90FLAGS)"
	@echo "FFLAGS_OPENBUFR = $(FFLAGS_OPENBUFR)"
	@echo "FFLAGS_OPENBIG  = $(FFLAGS_OPENBIG)"
	@echo "USER_FFLAGS     = $(USER_FFLAGS)"
	@echo "_D              = $(_D)"

#                  --------------------
#                  User Defined Targets
#                  --------------------

SRCS =	$(wildcard \
	abor1.f90 \
        adjtest.f90 \
	anberror.f90 \
	anbkerror_reg.f90 \
	anisofilter.f90 \
        antcorr_application.f90 \
	balmod.f90 \
	berror.f90 \
        bias_predictors.f90 \
	bkerror.f90 \
	bkgcov.f90 \
	bkgvar.f90 \
	bkgvar_rewgt.f90 \
	blacklist.f90 \
        calc_fov_conical.f90 \
        calc_fov_crosstrk.f90 \
	calctends.f90 \
	calctends_ad.F90 \
	calctends_tl.F90 \
	calctends_no_ad.F90 \
	calctends_no_tl.F90 \
	combine_radobs.f90 \
	compact_diffs.f90 \
	compute_derived.f90 \
	compute_fact10.f90 \
	constants.f90 \
        control2model.f90 \
        control2state.f90 \
        control_vectors.f90 \
	converr.f90 \
	convinfo.f90 \
	convthin.f90 \
        cvsection.f90 \
	deter_subdomain.f90 \
	dtast.f90 \
        enorm_state.F90 \
        evaljgrad.f90 \
        evaljcdfi.F90 \
        evaljo.f90 \
        evalqlim.f90 \
	fgrid2agrid_mod.f90 \
	fill_mass_grid2.f90 \
	fill_nmm_grid2.f90 \
	fpvsx_ad.f90 \
	gengrid_vars.f90 \
	genqsat.f90 \
	genstats_gps.f90 \
        geos_pertmod.F90 \
        geos_pgcmtest.F90 \
	gesinfo.F90 \
	get_derivatives.f90 \
	get_derivatives2.f90 \
	get_semimp_mats.f90 \
	getprs.f90 \
	getuv.f90 \
	getvvel.f90 \
	glbsoi.F90 \
        grtest.f90 \
	grdcrd.f90 \
	grid2sub.f90 \
	gridmod.f90 \
	gscond_ad.f90 \
	gsi_4dvar.f90 \
	gsi_io.f90 \
	gsimod.F90 \
	gsisub.F90 \
	guess_grids.F90 \
	half_nmm_grid2.f90 \
        inc2guess.f90 \
	init_commvars.f90 \
        init_jcdfi.F90 \
        int3dvar.f90 \
	intall.f90 \
	intdw.f90 \
	intgps.f90 \
	intjo.f90 \
	intlag.F90 \
	intlimq.f90 \
	intoz.f90 \
	intpcp.f90 \
	intps.f90 \
	intpw.f90 \
	intq.f90 \
	intrad.f90 \
	intrp2a.f90 \
	intrp3oz.f90 \
	intrppx.f90 \
	intrw.f90 \
	intspd.f90 \
	intsrw.f90 \
	intsst.f90 \
	intt.f90 \
        inttcp.f90 \
	intw.f90 \
	jcmod.f90 \
	jfunc.f90 \
	kinds.f90 \
        lag_fields.F90 \
        lag_interp.F90 \
        lag_traj.F90 \
	lagmod.f90 \
        lanczos.f90 \
        looplimits.f90 \
	m_berror_stats.F90 \
	m_dgeevx.F90 \
	m_gsiBiases.F90 \
        m_stats.F90 \
        m_tick.F90 \
        mpeu_mpif.F90 \
        mpeu_util.F90 \
	mod_inmi.f90 \
	mod_strong.f90 \
	mod_vtrans.F90 \
        model_ad.F90 \
        model_tl.F90 \
        model2control.f90 \
	mp_compact_diffs_mod1.f90 \
	mp_compact_diffs_support.f90 \
	mpimod.F90 \
        mpl_allreduce.f90 \
        mpl_bcast.f90 \
	ncepgfs_io.f90 \
	nlmsas_ad.f90 \
	normal_rh_to_q.f90 \
        obs_ferrscale.F90 \
	obs_para.f90 \
        obs_sensitivity.F90 \
        observer.F90 \
	obsmod.F90 \
	omegas_ad.f90 \
	oneobmod.F90 \
	ozinfo.f90 \
	pcgsoi.f90 \
	pcgsqrt.f90 \
	pcp_k.f90 \
	pcpinfo.f90 \
        penal.f90 \
	plib8.f90 \
	polcarf.f90 \
        prt_guess.f90 \
	precpd_ad.f90 \
	prewgt.f90 \
	prewgt_reg.f90 \
	psichi2uv_reg.f90 \
	psichi2uvt_reg.f90 \
	q_diag.f90 \
	qcmod.f90 \
	qcssmi.f90 \
        qnewton.f90 \
        qnewton3.F90 \
	radinfo.f90 \
	raflib.f90 \
	rdgrbsst.f90 \
	rdgstat_reg.f90 \
	read_airs.f90 \
	read_amsre.f90 \
	read_avhrr.f90 \
	read_avhrr_navy.f90 \
	read_bufrtovs.f90 \
	read_files.f90 \
	read_goesimg.f90 \
	read_goesndr.f90 \
	read_gps.f90 \
	read_guess.F90 \
	read_iasi.f90 \
	read_l2bufr_mod.f90 \
        read_lag.F90 \
	read_lidar.f90 \
	read_modsbufr.f90 \
	read_obs.F90 \
	read_obsdiags.F90 \
	read_ozone.F90 \
	read_pcp.f90 \
	read_prepbufr.f90 \
	read_radar.f90 \
	read_ssmi.f90 \
	read_ssmis.f90 \
	read_superwinds.f90 \
        read_tcps.f90 \
	read_wrf_mass_files.f90 \
	read_wrf_mass_guess.F90 \
	read_wrf_nmm_files.f90 \
	read_wrf_nmm_guess.F90 \
	regional_io.f90 \
	ret_ssmis.f90 \
	retrieval_amsre.f90 \
	retrieval_mi.f90 \
	rfdpar.f90 \
	rsearch.F90 \
	satthin.F90 \
        setupbend.f90 \
	setupdw.f90 \
        setupo3lv.f90 \
        setuplag.F90 \
	setupoz.f90 \
	setuppcp.f90 \
	setupps.f90 \
	setuppw.f90 \
	setupq.f90 \
	setuprad.f90 \
	setupref.f90 \
	setuprhsall.f90 \
	setuprw.f90 \
	setupspd.f90 \
	setupsrw.f90 \
	setupsst.f90 \
	setupt.f90 \
        setuptcp.f90 \
	setupw.f90 \
	setupyobs.f90 \
	sfc_model.f90 \
	simpin1.f90 \
	simpin1_init.f90 \
	smooth_polcarf.f90 \
	smoothrf.f90 \
	smoothwwrf.f90 \
	smoothzrf.f90 \
	specmod.f90 \
	spectral_transforms.f90 \
        sqrtmin.f90 \
	sst_retrieval.f90 \
        state2control.f90 \
        state_vectors.f90 \
	statsconv.f90 \
	statsoz.f90 \
	statspcp.f90 \
	statsrad.f90 \
	stop1.f90 \
	stp3dvar.f90 \
	stpcalc.f90 \
	stpdw.f90 \
	stpgps.f90 \
	stpjo.f90 \
	stplimq.f90 \
	stpoz.f90 \
	stppcp.f90 \
	stpps.f90 \
	stppw.f90 \
	stpq.f90 \
	stprad.f90 \
	stprw.f90 \
	stpspd.f90 \
	stpsrw.f90 \
	stpsst.f90 \
	stpt.f90 \
        stptcp.f90 \
	stpw.f90 \
	strong_bal_correction.f90 \
	strong_baldiag_inc.f90 \
	strong_fast_global_mod.f90 \
	strong_slow_global_mod.f90 \
	sub2grid.f90 \
	support_2dvar.f90 \
        tcv_mod.f90 \
	tendsmod.f90 \
        test_obsens.F90 \
        timermod.F90 \
	tintrp2a.f90 \
	tintrp3.f90 \
	tpause.f90 \
	tpause_t.F90 \
	transform.f90 \
	turbl.f90 \
	turbl_ad.f90 \
	turbl_tl.f90 \
	turblmod.f90 \
	tv_to_tsen.f90 \
	unfill_mass_grid2.f90 \
	unfill_nmm_grid2.f90 \
	unhalf_nmm_grid2.f90 \
	update_guess.f90 \
	update_geswtend.f90 \
	wrf_binary_interface.F90 \
	wrf_netcdf_interface.F90 \
	write_all.F90 \
	write_bkgvars_grid.f90 \
        write_obsdiags.F90 \
	wrwrfmassa.F90 \
	wrwrfnmma.F90 \
        xhat_vordivmod.f90 \
	zrnmi_mod.f90 \
	blockIO.c $(GSIGC_SRCS) )


ALLSRCS = $(SRCS) gsimain.F90 prepbykx.f

OBJS := $(addsuffix .o, $(basename $(SRCS)))
DEPS := $(addsuffix .d, $(basename $(ALLSRCS)))

_D = -D_GMAO_FVGSI_ -D_IGNORE_GRIDVERIFY_ $(GEOS_PERT)
_D =                                      $(GEOS_PERT)

ifeq ("$(FOPT)","-O3")
   FOPT += $(LOOP_VECT)
endif
FREAL      = $(FREAL4) 
FOPT_nobig = $(FOPT) $(BYTERECLEN) $(_D)
FPE        =

THIS_SP    = NCEP_sp_r8i4
THIS_W3    = NCEP_w3_r8i4
THIS_BACIO = NCEP_bacio_r4i4
THIS_BUFR  = NCEP_bufr_r8i4
THIS_GFSIO = NCEP_gfsio
LIB_GFSIO  = $(ESMADIR)/$(ARCH)/lib/lib$(THIS_GFSIO).a   # move to proper place
INC_GFSIO  = $(ESMADIR)/$(ARCH)/include/$(THIS_GFSIO)   # move to proper place

MOD_DIRS = . $(INC_ESMF) $(INC_HERMES) $(INC_CRTM) $(INC_IRSSE) \
	     $(INC_SIGIO) $(INC_GFSIO) \
             $(INC_SFCIO) $(INC_TRANSF) $(INC_IRUTIL) $(INC_RADTRANS) $(INC_GEOS) $(INC_MPI)
USER_FDEFS = $(_D) $(HAVE_ESMF)
USER_FFLAGS = -CB $(BIG_ENDIAN) $(BYTERECLEN)
USER_FFLAGS = $(BYTERECLEN)
USER_FFLAGS =
USER_FFLAGS = $(BIG_ENDIAN) $(BYTERECLEN)
USER_CFLAGS = -I . -Dfunder -DFortranByte=char -DFortranInt=int -DFortranLlong='long long' -O3
USER_FMODS  = $(foreach dir,$(MOD_DIRS),$(M)$(dir)) 

vpath % $(MOD_DIRS)

$(LIB) lib : $(OBJS)
	$(RM) $(LIB)
	$(AR) $(AR_FLAGS) $(LIB) $(OBJS)

%.x : $(LIB) %.o 
	$(LD) $(LDFLAGS) -o $@ $*.o $(LIB) $(LIB_SYS)

gsi.x:  $(OBJS) $(LIB) gsimain.o
	$(FC) $(LDFLAGS) -o gsi.x gsimain.o $(LIB) $(LIB_CRTM) $(LIB_IRSSE) \
	     $(LIB_SFCIO) $(LIB_BACIO)  $(LIB_BUFR) $(LIB_GFSIO) $(LIB_SIGIO) \
	     $(LIB_SP) $(LIB_W3) $(LIB_GMAO) \
	     $(LIB_SDF) $(LIB_MPI) $(LIB_SYS)

prepbykx.x: prepbykx.o
	$(LD) $(LDFLAGS) -o prepbykx.x prepbykx.o $(LIB_BUFR)

blockIO.o : blockIO.c
	@echo '---> Special handling of C code $<'
	$(CC) $(USER_CFLAGS) -c $<

blockIO.d : blockIO.c
	@ touch $@

# OBJS_OPENBUFR lists all i/o (OPEN) objects opened the same way as 
# NCEP_bufr files (native).

OBJS_OPENBUFR	= read_airs.o		\
		  read_amsre.o		\
		  read_avhrr.o		\
		  read_avhrr_navy.o	\
		  read_bufrtovs.o	\
		  read_goesimg.o	\
		  read_goesndr.o	\
		  read_gps.o		\
		  read_iasi.o		\
		  read_l2bufr_mod.o	\
		  read_lidar.o		\
		  read_modsbufr.o	\
		  read_ozone.o		\
		  read_pcp.o		\
		  read_prepbufr.o	\
		  read_radar.o		\
		  read_ssmi.o		\
		  read_ssmis.o		\
		  read_superwinds.o	\
		  oneobmod.o

$(OBJS_OPENBUFR) :
	@echo '---> Special handling of Fortran "native" BUFR-OPEN $<'
	$(FC) -c $(patsubst $(BIG_ENDIAN),,$(f90FLAGS)) $<

FFLAGS_OPENBUFR = $(patsubst $(BIG_ENDIAN),,$(f90FLAGS))

#
OBJS_OPENBIG	= m_berror_stats.o	\
		  balmod.o		\
		  prewgt.o

$(OBJS_OPENBIG) :
	@echo '---> Special handling of Fortran "big_endian" OPEN $<'
	$(FC) -c $(BIG_ENDIAN) $(f90FLAGS) $<

FFLAGS_OPENBIG = $(BIG_ENDIAN) $(f90FLAGS)

# Hack to prevent remaking dep files during cleaning
# --------------------------------------------------
  ifneq ($(findstring clean,$(MAKECMDGOALS)),clean)
    -include $(DEPS)
  endif

  -include $(ESMADIR)/Config/ESMA_post.mk  # ESMA additional targets, macros
#.
