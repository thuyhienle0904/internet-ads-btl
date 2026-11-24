# analysis.R -- single-file R pipeline for the Internet Advertisements project
# Probability and Statistics (MT2013), group 7, class CC08.
#
# This file merges the repository scripts, in the order of scripts/run_all.R:
#   01_data_setup.R -> 02_eda_descriptive.R (+ eda_terms.R) ->
#   03_inference_model.R -> 04_evaluation.R -> 05_inference_visuals.R
# together with their helper files (eda_helpers.R, inference_metrics.R,
# term_names.R). The code of each stage is unchanged except for three edits:
#   * the project root is the current working directory;
#   * the source() calls between scripts are removed (helpers are defined first);
#   * the original UCI feature names are embedded, so that docs/ and data/reference/
#     are not needed.
#
# Usage (base R only; no extra packages):
#   1. Place the unmodified Kaggle file add.csv in  data/raw/add.csv
#   2. From the project root (the folder that contains data/), run:
#        Rscript --encoding=UTF-8 analysis.R
#      Optional precision target for the threshold (default 0.70):
#        Rscript --encoding=UTF-8 analysis.R --min-precision=0.70
#
# Outputs
#   data/processed/   cleaned dataset (internet_ads_processed.csv) and audit tables
#   output/preprocessing/, output/eda-r/, output/inference/   tables and figures
#   report/figures/eda/, report/figures/inference/   figures used in the report

analysis_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
if (!file.exists(file.path(analysis_root, "data", "raw", "add.csv")))
  stop("Run from the project root with the unmodified file at data/raw/add.csv.")

# ============================================================================
# Embedded original UCI feature names (replaces docs/uci_feature_names.csv and
# data/reference/ad.names). Entries 1-4 are height, width, aratio, local;
# entries 5-1558 are the 1,554 term indicators in the column order of the CSV.
# ============================================================================
.uci_original_names <- c(
  "height", "width", "aratio", "local", "url*images+buttons", "url*likesbooks.com",
  "url*www.slake.com", "url*hydrogeologist", "url*oso", "url*media", "url*peace+images",
  "url*blipverts", "url*tkaine+kats", "url*labyrinth", "url*advertising+blipverts",
  "url*images+oso", "url*area51+corridor", "url*ran+gifs", "url*express-scripts.com",
  "url*off", "url*cnet", "url*time+1998", "url*josefina3", "url*truluck.com",
  "url*clawnext+gif", "url*autopen.com", "url*tvgen.com", "url*pixs", "url*heartland+5309",
  "url*meadows+9196", "url*blue", "url*ad+gif", "url*area51", "url*www.internauts.ca",
  "url*afn.org", "url*ran.org", "url*shareware.com", "url*baons+images",
  "url*area51+labyrinth", "url*pics", "url*image+navigate", "url*pool+images",
  "url*carousel.org", "url*members.accessus.net", "url*cmp+flowsoft010",
  "url*smallb+gif", "url*www.FlowSoft.com", "url*kandinsky", "url*csuhayward.edu",
  "url*www.yahoo.co.uk", "url*ibitexas.com", "url*www.haestad.com", "url*antiwar.com",
  "url*www.monmouth.com", "url*infoserver.etl.vt.edu", "url*geoguideii+tour",
  "url*heartland+pointe", "url*romancebooks+pix", "url*468x60", "url*ads.switchboard.com",
  "url*keith+dumble", "url*cqi.com", "url*images+ixfolder", "url*chat+b",
  "url*images+geoguideii", "url*preferences.com", "url*icsi.com", "url*pacific.net.sg",
  "url*monmouth.com", "url*wired.com", "url*go2net", "url*smiley+gif", "url*navigate+b",
  "url*sunsite.unc.edu", "url*www.pacific.net.sg", "url*home+gif", "url*library",
  "url*puc.edu", "url*internauts.ca", "url*www.worlddrugstore.com", "url*www.ibitexas.com",
  "url*ucsd.edu", "url*pitcairn+smallb", "url*kats", "url*cjackson+kandinsky",
  "url*tkaine+rings", "url*any+time", "url*FlowSoft.com", "url*geoguideii+nh",
  "url*charlie", "url*heartland+meadows", "url*home.netscape.com", "url*9439+butt2",
  "url*catringn+gif", "url*martnet", "url*doubleclick.net", "url*lycos.de",
  "url*catringn", "url*catring1", "url*fools+pixs", "url*logos", "url*private",
  "url*ng+spacedesc", "url*larx.com", "url*site", "url*pointe+1154", "url*banners",
  "url*pixs+smiley", "url*www.123greetings.com", "url*www.inwap.com", "url*cjackson",
  "url*labyrinth+9439", "url*generated+images", "url*image+ng", "url*lolnad+private",
  "url*library+pitcairn", "url*www.mei.co.jp", "url*april", "url*derived",
  "url*smiley", "url*home", "url*jsd", "url*sonic.net", "url*send+b", "url*website.ora.com",
  "url*pawbutton+gif", "url*victoria+pharmacy", "url*keith", "url*pages",
  "url*worlddrugstore.com", "url*geoguideii+email", "url*www.icgnet.com",
  "url*forum", "url*www.afn.org", "url*time", "url*www.ran.org", "url*main",
  "url*members+keith", "url*geoguideii+pages", "url*banner", "url*stinky+gra",
  "url*tkaine+buttons", "url*victoria", "url*kbell", "url*www.truluck.com",
  "url*img", "url*pics+cats", "url*alley", "url*claw1", "url*pharmacy+gif",
  "url*www.autopen.com", "url*images+img", "url*fbox.vt.edu", "url*unc.edu",
  "url*ics", "url*times", "url*forums", "url*chat", "url*images.go2net.com",
  "url*users.aol.com", "url*malek", "url*jsd+how", "url*www.cqi.com", "url*advertising+graphics",
  "url*pawbutton", "url*pictures", "url*grouper.com", "url*ads+media", "url*www.martnet.com",
  "url*set+butt", "url*how", "url*www.wednet.com", "url*www.globec.com.au",
  "url*athens", "url*info", "url*www.ireland-today.ie", "url*grn+bull", "url*sjsu.edu",
  "url*www.antiwar.com", "url*www.puc.edu", "url*sponsor", "url*www.news.com",
  "url*flowsoft010", "url*memberbanners", "url*red+ball", "url*ads.msn.com",
  "url*icons", "url*images", "url*access.ch", "url*irish+times", "url*media+images",
  "url*www.adamspharmacy.com", "url*geocities.com", "url*www.uk.lycos.de",
  "url*copymat.com", "url*hem1.passagen.se", "url*meadows", "url*grn", "url*gra",
  "url*vt.edu", "url*www.express-scripts.com", "url*imgs", "url*personal",
  "url*mindlink.net", "url*send", "url*pages+b", "url*accessus.net", "url*www.finest.tm.fr",
  "url*geoguideii+search", "url*polypkem", "url*fools", "url*www.larx.com",
  "url*marketplace", "url*wco.com", "url*off+gif", "url*tkaine+bars", "url*icgnet.com",
  "url*www.autotown.com", "url*generated", "url*9196+pawbutton", "url*geoguideii+chat",
  "url*www.vrn.de", "url*claw1+gif", "url*theinternetadvantage.com", "url*runofsite",
  "url*romancebooks", "url*foxy.net", "url*francois", "url*links", "url*athens+forum",
  "url*autotown.com", "url*logo", "url*members", "url*auto", "url*afn47757",
  "url*gifs", "url*esi", "url*hollywood", "url*forum+8078", "url*dept", "url*adamspharmacy.com",
  "url*valley", "url*www.pacificrim.net", "url*about", "url*www.likesbooks.com",
  "url*bossintl.com", "url*images+home", "url*wednet.com", "url*news.com",
  "url*arvann+images", "url*users", "url*netscape.com", "url*athens+8774",
  "url*pictures+gc", "url*butt", "url*e+gif", "url*sunsetstrip+alley", "url*geoguideii+send",
  "url*catring1+gif", "url*ball+gif", "url*bull", "url*paul.spu.edu", "url*rank",
  "url*2meta.com", "url*w+gif", "url*aol.com", "url*lg+gif", "url*irish-times.com",
  "url*irish", "url*ad.doubleclick.net", "url*ad.preferences.com", "url*bars",
  "url*forums+b", "url*gc+icon", "url*www.geocities.com", "url*www.carousel.org",
  "url*ball", "url*spu.edu", "url*com", "url*cnm", "url*htm+images", "url*htm+cmp",
  "url*cmp", "url*link+pics", "url*mindspring.com", "url*geoguideii+logo",
  "url*psu.edu", "url*go2net+ads", "url*www.grouper.com", "url*butt2", "url*cat",
  "url*www.dreamn.com", "url*vbtn+gif", "url*switchboard.com", "url*logo+b",
  "url*assets+images", "url*martnet.com", "url*buttons", "url*thejeep.com",
  "url*auto+generated", "url*search+b", "url*search", "url*pharmacy", "url*assets+auto",
  "url*static.wired.com", "url*cats", "url*bull+gif", "url*memberbanners+live",
  "url*pitcairn", "url*www.access.ch", "url*adv+images", "url*navigate",
  "url*runofsite+any", "url*dejay", "url*bishop", "url*email+b", "url*www.mcs.csuhayward.edu",
  "url*bin", "url*paris", "url*1154+graypaw", "url*stinky", "url*img+ads",
  "url*bds", "url*www.wco.com", "url*esi+image", "url*vrn.de", "url*www.toyotaofroswell.com",
  "url*www.copymat.com", "url*www.psnw.com", "url*go2net.com", "url*advertising",
  "url*slake.com", "url*www.theinternetadvantage.com", "url*baons", "url*geoguideii+rank",
  "url*butt2+gif", "url*tkaine", "url*art", "url*lovisa1", "url*pool", "url*valley+2647",
  "url*any", "url*corridor", "url*top", "url*rank+b", "url*pacificrim.net",
  "url*image", "url*heartland+valley", "url*tii", "url*123greetings.com",
  "url*adv", "url*ads", "url*hydrogeologist+imgs", "url*smallb", "url*members.tripod.com",
  "url*www.shareware.com", "url*images+ads", "url*banner+gif", "url*vbtn",
  "url*globec.com.au", "url*www.news-observer.com", "url*pointe", "url*mandypaul",
  "url*bds+s", "url*www.ems.psu.edu", "url*valley+2539", "url*members.aol.com",
  "url*yahoo.co.uk", "url*malek+small", "url*button", "url*msn.com", "url*graypaw+gif",
  "url*live", "url*haestad.com", "url*sanjosesabercats.com", "url*icon+gif",
  "url*april+fools", "url*assets", "url*set", "url*link", "url*wc", "url*uk",
  "url*sj", "url*images+set", "url*www.bossintl.com", "url*nh", "url*ng",
  "url*counter", "url*lg", "url*spacedesc", "url*bishop+red", "url*it", "url*ie",
  "url*rings", "url*gc", "url*peace", "url*dreamn.com", "url*ar", "url*ad",
  "url*thumb", "url*clawnext", "url*dumble", "url*kandinsky+t", "url*email",
  "url*martnet+images", "url*uk+gif", "url*red", "url*geoguideii+forums",
  "url*www.2meta.com", "url*ran", "url*ukonline.co.uk", "url*passagen.se",
  "url*psnw.com", "url*how+htm", "url*tm.fr", "url*sunsetstrip", "url*ora.com",
  "url*logo+gif", "url*marketing", "url*toyotaofroswell.com", "url*heartland",
  "url*ixfolder+gif", "url*mcet.edu", "url*enchantedforest", "url*alley+6750",
  "url*news-observer.com", "url*ireland-today.ie", "url*times+graphics",
  "url*madamecleo", "url*b+gif", "url*www.irish-times.com", "url*tripod.com",
  "url*ad+icons", "url*button+gif", "url*graypaw", "url*excite.com", "url*web.ukonline.co.uk",
  "url*polypkem+grn", "url*gort.ucsd.edu", "url*lolnad", "url*graphics+ad",
  "url*icon", "url*falcon.sonic.net", "url*picts", "url*phoenix.mcet.edu",
  "url*pix+b", "url*www.icsi.com", "url*ixfolder", "url*inwap.com", "url*www.cob.sjsu.edu",
  "url*pix", "url*www.thejeep.com", "url*tour", "url*www.sanjosesabercats.com",
  "url*mei.co.jp", "url*geoguideii", "url*small", "url*graphics", "url*kbell+charlie",
  "url*zueri.ch", "url*arvann", "origurl*labyrinth", "origurl*puc.edu", "origurl*charlie+charlie",
  "origurl*hevern+psychref", "origurl*and", "origurl*pterry+htm", "origurl*bishop",
  "origurl*ora.com", "origurl*www.nyx.net", "origurl*www.yahoo.co.uk", "origurl*www.truluck.com",
  "origurl*target+\u00aeion", "origurl*tkaine+sydkat", "origurl*meadows+9196",
  "origurl*top", "origurl*members.xoom.com", "origurl*0+rpp", "origurl*www.thriveonline.com",
  "origurl*adamspharmacy.com", "origurl*icsi.com", "origurl*tkaine+stvkat",
  "origurl*shareware.com", "origurl*e+html", "origurl*www.123greetings.com",
  "origurl*lofts+7119", "origurl*likesbooks.com", "origurl*gort.ucsd.edu",
  "origurl*users.aol.com", "origurl*www.innotts.co.uk", "origurl*roll.com",
  "origurl*web.ukonline.co.uk", "origurl*events", "origurl*www.2meta.com",
  "origurl*chuck+html", "origurl*paris", "origurl*chapel", "origurl*tii",
  "origurl*how+title", "origurl*www.news-observer.com", "origurl*alley",
  "origurl*april+fools", "origurl*carousel", "origurl*www.haestad.com", "origurl*title+html",
  "origurl*lemoyne.edu", "origurl*plains+5257", "origurl*psychref", "origurl*jun",
  "origurl*www.interchg.ubc.ca", "origurl*ukonline.co.uk", "origurl*www.lycos.co.uk",
  "origurl*lolnad+private", "origurl*ibitexas.com", "origurl*wco.com", "origurl*jsd",
  "origurl*www.rock.n.roll.com", "origurl*antiwar.com", "origurl*target",
  "origurl*phoenix.mcet.edu", "origurl*index", "origurl*1154+index", "origurl*pharmacy",
  "origurl*coltrane", "origurl*website.ora.com", "origurl*index+htm", "origurl*dept",
  "origurl*area51+labyrinth", "origurl*irish-times.com", "origurl*mandypaul",
  "origurl*pointe", "origurl*plato+htm", "origurl*arvann", "origurl*\u00aeion+0",
  "origurl*chapel+safehaven", "origurl*worldvillage.com", "origurl*nf+htm",
  "origurl*www.martnet.com", "origurl*hem1.passagen.se", "origurl*worlddrugstore.com",
  "origurl*www.globec.com.au", "origurl*athens+8774", "origurl*times+paper",
  "origurl*actup", "origurl*inwap", "origurl*main", "origurl*www.larx.com",
  "origurl*dumble+contents", "origurl*geocities.com", "origurl*4301+misfits2",
  "origurl*kattsida", "origurl*members.aol.com", "origurl*spu.edu", "origurl*sunsite.unc.edu",
  "origurl*valley+2647", "origurl*josefina3", "origurl*tkaine", "origurl*bonchin+cat",
  "origurl*chopin+htm", "origurl*punkie", "origurl*ubc.ca", "origurl*links+nf",
  "origurl*misfits2", "origurl*area51+vault", "origurl*kitty", "origurl*plato",
  "origurl*hollywood+7735", "origurl*link", "origurl*www.monmouth.com", "origurl*hist",
  "origurl*members.tripod.com", "origurl*www.ibitexas.com", "origurl*cgidir+dll",
  "origurl*heartland", "origurl*pages+catscats", "origurl*tkaine+linda",
  "origurl*crawler", "origurl*paul.spu.edu", "origurl*bishop+pterry", "origurl*carousel.org",
  "origurl*romance", "origurl*nyx.net", "origurl*hollywood", "origurl*simonc",
  "origurl*sox", "origurl*www.cob.sjsu.edu", "origurl*timeout+5", "origurl*leonora",
  "origurl*fh-rpl.de", "origurl*vt.edu", "origurl*ucsd.edu", "origurl*www.carousel.org",
  "origurl*www.antiwar.com", "origurl*FlowSoft.com", "origurl*kbell+charlie",
  "origurl*www.likesbooks.com", "origurl*labyrinth+9439", "origurl*www.icsi.com",
  "origurl*events+aprilfoolsday", "origurl*tii+tii", "origurl*athens+forum",
  "origurl*library", "origurl*valley", "origurl*ics+ikenobo", "origurl*unc.edu",
  "origurl*kandin", "origurl*bordeaux", "origurl*charlie", "origurl*6750+paws",
  "origurl*cccats", "origurl*linda+htm", "origurl*2647+coltrane", "origurl*vault+3440",
  "origurl*victoria+pharmacy", "origurl*wv", "origurl*kandin+html", "origurl*soho+lofts",
  "origurl*sunsetstrip+alley", "origurl*slake.com", "origurl*autotown.com",
  "origurl*www.sanjosesabercats.com", "origurl*infoserver.etl.vt.edu", "origurl*kushmerick",
  "origurl*www.toyotaofroswell.com", "origurl*turbo", "origurl*sw", "origurl*hills",
  "origurl*st", "origurl*mogwhi", "origurl*sj", "origurl*pointe+1154", "origurl*monmouth.com",
  "origurl*mei.co.jp", "origurl*sonic.net", "origurl*safehaven+index", "origurl*simonc+cybermog",
  "origurl*messier", "origurl*cybercats", "origurl*search", "origurl*heartland+5309",
  "origurl*psnw.com", "origurl*keith+dumble", "origurl*links", "origurl*nav",
  "origurl*nf", "origurl*sunsetstrip", "origurl*kandinsky", "origurl*meadows+3727",
  "origurl*www.afn.org", "origurl*southbeach", "origurl*pacific.net.sg",
  "origurl*heartland+pointe", "origurl*valley+2539", "origurl*catscats+html",
  "origurl*horn+html", "origurl*area51", "origurl*pages", "origurl*chopin",
  "origurl*it", "origurl*bonchin", "origurl*www.worldvillage.com", "origurl*00+html",
  "origurl*vrn.de", "origurl*home.netscape.com", "origurl*simstory+html",
  "origurl*biopic+htm", "origurl*dll", "origurl*cmeese+malibu", "origurl*ics",
  "origurl*linda", "origurl*fr", "origurl*private+biopic", "origurl*corridor+4590",
  "origurl*leonora+html", "origurl*dejay", "origurl*aprilfoolsday", "origurl*fools",
  "origurl*biopic", "origurl*lofts", "origurl*heartland+plains", "origurl*passagen.se",
  "origurl*djang", "origurl*5257+timstory", "origurl*5+hpe", "origurl*cybermog+htm",
  "origurl*area51+corridor", "origurl*yosemite+4301", "origurl*wosc+html",
  "origurl*rpp", "origurl*personal", "origurl*express-scripts.com", "origurl*madamecleo",
  "origurl*malibu", "origurl*sjsu.edu", "origurl*news", "origurl*www.ems.psu.edu",
  "origurl*7735+mcp", "origurl*sox+htm", "origurl*mcet.edu", "origurl*punkie+htm",
  "origurl*midnite", "origurl*foxy.net", "origurl*maple.lemoyne.edu", "origurl*times",
  "origurl*news.com", "origurl*4010+index", "origurl*www.slake.com", "origurl*larx.com",
  "origurl*www.FlowSoft.com", "origurl*paper", "origurl*members+keith", "origurl*paper+1998",
  "origurl*inwap.com", "origurl*www.tkz.fh-rpl.de", "origurl*members.accessus.net",
  "origurl*kattsida+html", "origurl*cjackson+kandinsky", "origurl*main+htm",
  "origurl*www.mei.co.jp", "origurl*www.adamspharmacy.com", "origurl*20+timeout",
  "origurl*corridor+5139", "origurl*falcon.sonic.net", "origurl*lycos.co.uk",
  "origurl*ran", "origurl*afn47757+midnite", "origurl*www.vrn.de", "origurl*5309+index",
  "origurl*stvkat+htm", "origurl*hpe", "origurl*wv+square", "origurl*keith",
  "origurl*www.pacificrim.net", "origurl*how", "origurl*www.metacrawler.com",
  "origurl*pacificrim.net", "origurl*5257+simstory", "origurl*cmeese", "origurl*metacrawler.com",
  "origurl*catscats", "origurl*wosc", "origurl*xoom.com", "origurl*innotts.co.uk",
  "origurl*paris+3963", "origurl*general+kushmerick", "origurl*mindlink.net",
  "origurl*cybermog", "origurl*kerouac+htm", "origurl*internauts.ca", "origurl*mcp",
  "origurl*martnet.com", "origurl*toyotaofroswell.com", "origurl*msheryl",
  "origurl*vault", "origurl*malibu+html", "origurl*jsd+how", "origurl*polypkem+index",
  "origurl*corridor", "origurl*zoe+html", "origurl*afn.org", "origurl*theinternetadvantage.com",
  "origurl*coltrane+htm", "origurl*timeout", "origurl*8078+home", "origurl*turbo+html",
  "origurl*heartland+meadows", "origurl*news-observer.com", "origurl*www.psnw.com",
  "origurl*contents+html", "origurl*tkaine+mogwhi", "origurl*stanford.edu",
  "origurl*www.bossintl.com", "origurl*general", "origurl*switchboard.com",
  "origurl*cgidir", "origurl*access.ch", "origurl*sydkat+htm", "origurl*hotsprings",
  "origurl*baons", "origurl*peace", "origurl*2647+chopin", "origurl*www.worlddrugstore.com",
  "origurl*actup+index", "origurl*bin+cgidir", "origurl*www.internauts.ca",
  "origurl*library+pitcairn", "origurl*inwap+cats", "origurl*lolnad", "origurl*pterry",
  "origurl*lovisa1", "origurl*www.dreamn.com", "origurl*polypkem", "origurl*tm.fr",
  "origurl*athens", "origurl*copymat.com", "origurl*soho", "origurl*victoria",
  "origurl*bossintl.com", "origurl*westhollywood", "origurl*private", "origurl*cat",
  "origurl*cats+htm", "origurl*malek+kandin", "origurl*yosemite", "origurl*www.inwap.com",
  "origurl*afn47757+plato", "origurl*timstory", "origurl*excite.com", "origurl*forum+8078",
  "origurl*cats", "origurl*kitty+and", "origurl*dreamn.com", "origurl*irish+times",
  "origurl*crawler+general", "origurl*bordeaux+actup", "origurl*hotsprings+4527",
  "origurl*kbell", "origurl*stinky+cats", "origurl*plains", "origurl*netscape.com",
  "origurl*csuhayward.edu", "origurl*safehaven", "origurl*tripod.com", "origurl*alley+6750",
  "origurl*sanjosesabercats.com", "origurl*www.news.com", "origurl*mogwhi+htm",
  "origurl*www.theinternetadvantage.com", "origurl*thejeep.com", "origurl*3963+leonora",
  "origurl*www.wednet.com", "origurl*autopen.com", "origurl*charlie+html",
  "origurl*forum", "origurl*kaitlin", "origurl*april", "origurl*grouper.com",
  "origurl*www.ran.org", "origurl*sydkat", "origurl*heartland+6712", "origurl*rpp+20",
  "origurl*2647+kaitlin", "origurl*psychref+html", "origurl*josefina3+horn",
  "origurl*malek", "origurl*stvkat", "origurl*timstory+html", "origurl*corp",
  "origurl*story", "origurl*thriveonline.com", "origurl*bds+punkie", "origurl*zoe",
  "origurl*kerouac", "origurl*123greetings.com", "origurl*2647+kerouac",
  "origurl*www.access.ch", "origurl*www.express-scripts.com", "origurl*paws",
  "origurl*wednet.com", "origurl*francois", "origurl*zdnet.com", "origurl*simstory",
  "origurl*www.puc.edu", "origurl*www.irish-times.com", "origurl*www.copymat.com",
  "origurl*cjackson", "origurl*kaitlin+htm", "origurl*tori+html", "origurl*southbeach+7597",
  "origurl*home+html", "origurl*hpe+10", "origurl*pad+htm", "origurl*psu.edu",
  "origurl*www.shareware.com", "origurl*bin", "origurl*arvann+pages", "origurl*tori",
  "origurl*dumble", "origurl*www.icgnet.com", "origurl*romancebooks", "origurl*3727+turbo",
  "origurl*football", "origurl*msheryl+djang", "origurl*zueri.ch", "origurl*aol.com",
  "origurl*bds", "origurl*cat+html", "origurl*and+tori", "origurl*hollywood+9662",
  "origurl*djang+html", "origurl*yahoo.co.uk", "origurl*truluck.com", "origurl*shtml",
  "origurl*link+chuck", "origurl*members", "origurl*www.thejeep.com", "origurl*2meta.com",
  "origurl*cats+html", "origurl*www.autopen.com", "origurl*hevern", "origurl*ikenobo",
  "origurl*accessus.net", "origurl*www.wco.com", "origurl*contents", "origurl*pitcairn",
  "origurl*westhollywood+4010", "origurl*messier+html", "origurl*icgnet.com",
  "origurl*mandypaul+main", "origurl*links+carousel", "origurl*square+chapel",
  "origurl*www.grouper.com", "origurl*6712+cats", "origurl*www.MeissnerChevrolet.autotown.com",
  "origurl*globec.com.au", "origurl*meadows", "origurl*afn47757", "origurl*www.geocities.com",
  "origurl*haestad.com", "origurl*midnite+htm", "origurl*tkaine+sox", "origurl*lovisa1+kattsida",
  "origurl*fr+bordeaux", "origurl*mindspring.com", "origurl*7597+kitty",
  "origurl*wired.com", "origurl*paws+pad", "origurl*irish", "origurl*square",
  "origurl*pad", "origurl*method", "origurl*www.mcs.csuhayward.edu", "origurl*www.pacific.net.sg",
  "origurl*chuck", "origurl*ran.org", "origurl*misfits2+htm", "origurl*stinky",
  "origurl*horn", "origurl*heartland+valley", "origurl*heartland+hills",
  "origurl*www.finest.tm.fr", "origurl*carousel+links", "origurl*kushmerick+method",
  "origurl*txt", "origurl*method+0", "origurl*title", "origurl*fbox.vt.edu",
  "origurl*index+html", "origurl*asp", "origurl*mcp+htm", "origurl*home",
  "origurl*netcenter", "origurl*hydrogeologist", "origurl*2539+index", "origurl*teams",
  "origurl*\u00aeion", "ancurl*search+direct", "ancurl*likesbooks.com", "ancurl*mirror",
  "ancurl*www.slake.com", "ancurl*cnet+cat", "ancurl*hydrogeologist", "ancurl*geoguide",
  "ancurl*2fcrawler", "ancurl*clawring+htm", "ancurl*tkaine+kats", "ancurl*labyrinth",
  "ancurl*clickthru+clickid", "ancurl*redirect", "ancurl*com+ads", "ancurl*area51+corridor",
  "ancurl*express-scripts.com", "ancurl*cnet", "ancurl*time+1998", "ancurl*josefina3",
  "ancurl*truluck.com", "ancurl*cgiadman", "ancurl*linkpg+htm", "ancurl*geoguide+rank",
  "ancurl*area51", "ancurl*www.internauts.ca", "ancurl*afn.org", "ancurl*www.microsoft.com",
  "ancurl*nph", "ancurl*ran.org", "ancurl*comprod+mirror", "ancurl*shareware.com",
  "ancurl*jump", "ancurl*area51+labyrinth", "ancurl*pics", "ancurl*nsads.hotwired.com",
  "ancurl*new", "ancurl*net", "ancurl*relocate+ad", "ancurl*sendform", "ancurl*carousel.org",
  "ancurl*members.accessus.net", "ancurl*home+htm", "ancurl*index+html",
  "ancurl*www.FlowSoft.com", "ancurl*kandinsky", "ancurl*csuhayward.edu",
  "ancurl*www.yahoo.co.uk", "ancurl*ibitexas.com", "ancurl*www.monmouth.com",
  "ancurl*infoserver.etl.vt.edu", "ancurl*heartland+pointe", "ancurl*msn",
  "ancurl*468x60", "ancurl*bin+click", "ancurl*general", "ancurl*keith+dumble",
  "ancurl*cqi.com", "ancurl*heartland+plains", "ancurl*redir", "ancurl*webring.org",
  "ancurl*uk+sv", "ancurl*mem", "ancurl*next", "ancurl*pacific.net.sg", "ancurl*monmouth.com",
  "ancurl*news", "ancurl*adclick", "ancurl*default", "ancurl*exe+cid", "ancurl*claw",
  "ancurl*bin+webring", "ancurl*emailbox", "ancurl*sunsite.unc.edu", "ancurl*exec+obidos",
  "ancurl*obidos", "ancurl*www.pacific.net.sg", "ancurl*library", "ancurl*puc.edu",
  "ancurl*internauts.ca", "ancurl*n+a", "ancurl*www.ibitexas.com", "ancurl*ucsd.edu",
  "ancurl*kats", "ancurl*cjackson+kandinsky", "ancurl*clickid", "ancurl*any+time",
  "ancurl*1+cid", "ancurl*ring", "ancurl*FlowSoft.com", "ancurl*nph+adclick",
  "ancurl*adclick+exe", "ancurl*event", "ancurl*general+site", "ancurl*2fclick",
  "ancurl*home.netscape.com", "ancurl*bin+homestead", "ancurl*click+runid",
  "ancurl*martnet", "ancurl*doubleclick.net", "ancurl*st+uk", "ancurl*catring+html",
  "ancurl*ng+spacedesc", "ancurl*familyid", "ancurl*yahoo", "ancurl*site",
  "ancurl*redirect+dll", "ancurl*pointe+1154", "ancurl*home+html", "ancurl*www.123greetings.com",
  "ancurl*cat+general", "ancurl*www.inwap.com", "ancurl*cjackson", "ancurl*labyrinth+9439",
  "ancurl*library+pitcairn", "ancurl*www.mei.co.jp", "ancurl*april", "ancurl*comprod",
  "ancurl*ukie", "ancurl*home", "ancurl*www.lycos.co.uk", "ancurl*jsd", "ancurl*ans+entry",
  "ancurl*keith", "ancurl*www.icgnet.com", "ancurl*forum", "ancurl*redirect+cgi",
  "ancurl*www.afn.org", "ancurl*geoguide+emailme", "ancurl*time", "ancurl*www.ran.org",
  "ancurl*main", "ancurl*members+keith", "ancurl*http+ad", "ancurl*2f+2fwww",
  "ancurl*ad+bin", "ancurl*www.amazon.com", "ancurl*4+mem", "ancurl*www.truluck.com",
  "ancurl*bridalinfo", "ancurl*pics+cats", "ancurl*direct", "ancurl*image+http",
  "ancurl*fbox.vt.edu", "ancurl*unc.edu", "ancurl*d+ukie", "ancurl*forums",
  "ancurl*co+uk", "ancurl*e+html", "ancurl*inwap+cats", "ancurl*malek", "ancurl*jsd+how",
  "ancurl*www.cqi.com", "ancurl*redirect+http", "ancurl*name", "ancurl*1+d",
  "ancurl*kat001", "ancurl*magic+adclick", "ancurl*grouper.com", "ancurl*readersndex+com",
  "ancurl*excite+468x60", "ancurl*click+ng", "ancurl*www.martnet.com", "ancurl*http+2f",
  "ancurl*direct+topic", "ancurl*how", "ancurl*www.wednet.com", "ancurl*www.globec.com.au",
  "ancurl*athens", "ancurl*info", "ancurl*schwab", "ancurl*sjsu.edu", "ancurl*www.puc.edu",
  "ancurl*a+uk", "ancurl*www.news.com", "ancurl*2fclick+ng", "ancurl*ads.msn.com",
  "ancurl*images", "ancurl*access.ch", "ancurl*home+ring", "ancurl*plug.go2net.com",
  "ancurl*geocities.com", "ancurl*geoguide+tour", "ancurl*copymat.com", "ancurl*www.webring.org",
  "ancurl*groupid+1", "ancurl*gif+pk", "ancurl*dll+cid", "ancurl*adid", "ancurl*vt.edu",
  "ancurl*worlddrug.com", "ancurl*edition", "ancurl*www.express-scripts.com",
  "ancurl*personal", "ancurl*gid", "ancurl*bin+geoguide", "ancurl*mindlink.net",
  "ancurl*accessus.net", "ancurl*type", "ancurl*ng+type", "ancurl*polypkem",
  "ancurl*fools", "ancurl*bin+cgiadman", "ancurl*marketplace", "ancurl*wco.com",
  "ancurl*links+html", "ancurl*tkaine+bars", "ancurl*icgnet.com", "ancurl*www.autotown.com",
  "ancurl*adcount+plx", "ancurl*1+familyid", "ancurl*yahoo.com", "ancurl*page",
  "ancurl*theinternetadvantage.com", "ancurl*runofsite", "ancurl*romancebooks",
  "ancurl*francois", "ancurl*links", "ancurl*athens+forum", "ancurl*site+sw",
  "ancurl*autotown.com", "ancurl*amazon.com", "ancurl*site+ne", "ancurl*qual",
  "ancurl*members", "ancurl*exe", "ancurl*pratchett", "ancurl*afn47757",
  "ancurl*esi", "ancurl*1154+linkpg", "ancurl*desc", "ancurl*forum+8078",
  "ancurl*topic", "ancurl*bin+acc", "ancurl*valley", "ancurl*delv", "ancurl*family",
  "ancurl*lspace.org", "ancurl*www.pacificrim.net", "ancurl*about", "ancurl*webring+ring",
  "ancurl*www.likesbooks.com", "ancurl*bossintl.com", "ancurl*runid", "ancurl*wednet.com",
  "ancurl*news.com", "ancurl*lycos.co.uk", "ancurl*arvann+images", "ancurl*526+redirect",
  "ancurl*ads+msn", "ancurl*netscape.com", "ancurl*athens+8774", "ancurl*click+profileid",
  "ancurl*qual+mc", "ancurl*homestead+ans", "ancurl*paul.spu.edu", "ancurl*dll",
  "ancurl*readersndex", "ancurl*dir", "ancurl*rank", "ancurl*2meta.com",
  "ancurl*Lpage.com", "ancurl*emailme", "ancurl*event+ng", "ancurl*3a+2fcrawler",
  "ancurl*cgiadman+dll", "ancurl*aol.com", "ancurl*lg+gif", "ancurl*magic",
  "ancurl*bin+ad", "ancurl*www.worlddrug.com", "ancurl*ring+midnight", "ancurl*irish-times.com",
  "ancurl*download", "ancurl*http+www", "ancurl*homepage", "ancurl*midnight+id",
  "ancurl*ad.doubleclick.net", "ancurl*exec", "ancurl*mem+1", "ancurl*msn+com",
  "ancurl*preferences", "ancurl*contact", "ancurl*bars", "ancurl*products",
  "ancurl*www.geocities.com", "ancurl*www.carousel.org", "ancurl*spu.edu",
  "ancurl*com", "ancurl*cnm", "ancurl*webring+home", "ancurl*link+pics",
  "ancurl*cid", "ancurl*psu.edu", "ancurl*ads+redirect", "ancurl*cfm", "ancurl*www.grouper.com",
  "ancurl*member", "ancurl*index", "ancurl*cat", "ancurl*www.dreamn.com",
  "ancurl*afn47757+clawring", "ancurl*switchboard.com", "ancurl*ad+preferences",
  "ancurl*inwap", "ancurl*adcount", "ancurl*martnet.com", "ancurl*thejeep.com",
  "ancurl*search", "ancurl*shtml", "ancurl*www+yahoo", "ancurl*desc+4", "ancurl*cats",
  "ancurl*pitcairn", "ancurl*www.access.ch", "ancurl*runofsite+any", "ancurl*url",
  "ancurl*dejay", "ancurl*gallery", "ancurl*bishop", "ancurl*features+forums",
  "ancurl*area", "ancurl*www.mcs.csuhayward.edu", "ancurl*bin", "ancurl*bds",
  "ancurl*www.wco.com", "ancurl*www.toyotaofroswell.com", "ancurl*www.copymat.com",
  "ancurl*go2net.com", "ancurl*delv+dir", "ancurl*slake.com", "ancurl*www+readersndex",
  "ancurl*www.theinternetadvantage.com", "ancurl*edition+cnet", "ancurl*tkaine",
  "ancurl*catring", "ancurl*asp", "ancurl*art", "ancurl*relocate", "ancurl*468x60+runofsite",
  "ancurl*valley+2647", "ancurl*any", "ancurl*ans", "ancurl*corridor", "ancurl*amp",
  "ancurl*top", "ancurl*pacificrim.net", "ancurl*image", "ancurl*heartland+valley",
  "ancurl*tii", "ancurl*123greetings.com", "ancurl*ads", "ancurl*www.yahoo.com",
  "ancurl*cuteftp", "ancurl*acc", "ancurl*bin+search", "ancurl*www.shareware.com",
  "ancurl*dir+qual", "ancurl*globec.com.au", "ancurl*www.news-observer.com",
  "ancurl*index+htm", "ancurl*xmission.com", "ancurl*ukie+s", "ancurl*629+redirect",
  "ancurl*pointe", "ancurl*www.ems.psu.edu", "ancurl*http+ads", "ancurl*members.aol.com",
  "ancurl*www.xmission.com", "ancurl*yahoo.co.uk", "ancurl*ring+kat001",
  "ancurl*msn.com", "ancurl*groupid", "ancurl*geoguide+geoguide", "ancurl*sanjosesabercats.com",
  "ancurl*excite", "ancurl*april+fools", "ancurl*slagen", "ancurl*link",
  "ancurl*tour+member", "ancurl*uk", "ancurl*people", "ancurl*sw", "ancurl*sv",
  "ancurl*st", "ancurl*sj", "ancurl*pl", "ancurl*pk", "ancurl*www.bossintl.com",
  "ancurl*ng", "ancurl*ne", "ancurl*mc", "ancurl*lg", "ancurl*spacedesc",
  "ancurl*it", "ancurl*ie", "ancurl*id", "ancurl*go", "ancurl*gg", "ancurl*homestead",
  "ancurl*bin+nph", "ancurl*peace", "ancurl*t+s", "ancurl*de", "ancurl*co",
  "ancurl*dreamn.com", "ancurl*plx+http", "ancurl*ad", "ancurl*rnd", "ancurl*dumble",
  "ancurl*kandinsky+p", "ancurl*linkpg", "ancurl*webring", "ancurl*ref",
  "ancurl*www.2meta.com", "ancurl*ran", "ancurl*ukonline.co.uk", "ancurl*www.Lpage.com",
  "ancurl*2fwww", "ancurl*ring+claw", "ancurl*midnight", "ancurl*hotwired.com",
  "ancurl*how+htm", "ancurl*tm.fr", "ancurl*ora.com", "ancurl*marketing",
  "ancurl*toyotaofroswell.com", "ancurl*heartland", "ancurl*s+b", "ancurl*mcet.edu",
  "ancurl*clickthru", "ancurl*enchantedforest", "ancurl*clawring", "ancurl*news-observer.com",
  "ancurl*plains", "ancurl*entry", "ancurl*acc+clickthru", "ancurl*3a", "ancurl*www.irish-times.com",
  "ancurl*2f", "ancurl*dll+type", "ancurl*soho", "ancurl*features", "ancurl*adclick+id",
  "ancurl*click", "ancurl*preferences+com", "ancurl*claw+id", "ancurl*url+http",
  "ancurl*microsoft.com", "ancurl*excite.com", "ancurl*web.ukonline.co.uk",
  "ancurl*gort.ucsd.edu", "ancurl*com+home", "ancurl*2fcgi", "ancurl*pub",
  "ancurl*bin+adcount", "ancurl*mc+3a", "ancurl*phoenix.mcet.edu", "ancurl*plx",
  "ancurl*inwap.com", "ancurl*www.cob.sjsu.edu", "ancurl*www.thejeep.com",
  "ancurl*tour", "ancurl*www.sanjosesabercats.com", "ancurl*mei.co.jp", "ancurl*geoguide+sendform",
  "ancurl*services", "ancurl*type+click", "ancurl*tagvalues", "ancurl*profileid",
  "ancurl*zueri.ch", "ancurl*arvann", "ancurl*tagvalues+13", "alt*your",
  "alt*and", "alt*top", "alt*all", "alt*email", "alt*out", "alt*our", "alt*here",
  "alt*the", "alt*download", "alt*netscape", "alt*what", "alt*explorer",
  "alt*more", "alt*for+a", "alt*take+a", "alt*kitty", "alt*visit+our", "alt*link",
  "alt*wacky", "alt*like", "alt*heartland", "alt*visit+the", "alt*romance",
  "alt*online", "alt*products", "alt*now", "alt*click+here", "alt*pages+like",
  "alt*rank", "alt*information", "alt*us", "alt*send+this", "alt*up", "alt*to",
  "alt*chat", "alt*new", "alt*net", "alt*my+site", "alt*search", "alt*this",
  "alt*on", "alt*of", "alt*links", "alt*bytes", "alt*my", "alt*me", "alt*picture",
  "alt*club", "alt*pages", "alt*this+page", "alt*in", "alt*on+the", "alt*guestbook",
  "alt*by", "alt*click", "alt*at", "alt*ad", "alt*mine", "alt*amazon+com",
  "alt*web", "alt*next", "alt*news", "alt*info", "alt*join", "alt*of+the",
  "alt*book", "alt*amazon", "alt*forums", "alt*back", "alt*next+site", "alt*a+tour",
  "alt*com", "alt*microsoft", "alt*geocities", "alt*ring", "alt*cat", "alt*send",
  "alt*internet+explorer", "alt*banner", "alt*home+page", "alt*internet",
  "alt*find", "alt*cool", "alt*my+guestbook", "alt*here+for", "alt*with",
  "alt*get", "alt*take", "alt*tour", "alt*site", "alt*to+visit", "alt*rank+my",
  "alt*from", "alt*page", "alt*graphic", "alt*like+mine", "alt*email+me",
  "alt*visit", "alt*free", "alt*the+kat", "alt*award", "alt*services", "alt*about",
  "alt*for", "alt*here+to", "alt*network", "alt*you", "alt*logo", "alt*home",
  "alt*kat", "caption*and", "caption*home+page", "caption*click+here", "caption*the",
  "caption*pratchett", "caption*here+for", "caption*site", "caption*page",
  "caption*to", "caption*of", "caption*home", "caption*my", "caption*your",
  "caption*in", "caption*bytes", "caption*here", "caption*click", "caption*for",
  "caption*you"
)
uci_feature_names <- data.frame(Raw_Column_Name = as.character(0:1557),
                                Original_UCI_Name = .uci_original_names,
                                stringsAsFactors = FALSE)
# Original names of the 1,554 term indicators (Kaggle columns 4..1557).
load_term_names <- function(root) {
  stats::setNames(.uci_original_names[5:1558], sprintf("term_%04d", 4:1557))
}

# ============================================================================
# Helper functions (scripts/eda_helpers.R)
# ============================================================================
# Base-R EDA functions. Source this file without running a data pipeline.
validate_eda <- function(data, config) {
  required <- c("label_col", "numeric_cols", "binary_cols", "plot_numeric_cols",
                "plot_binary_cols", "expected_labels", "scope", "output_dir")
  if (!all(required %in% names(config))) stop("Incomplete EDA configuration.")
  if (!is.data.frame(data) || nrow(data) == 0L) stop("Expected a non-empty data frame.")
  if (anyDuplicated(names(data))) stop("Duplicate column names.")
  if (length(config$label_col) != 1L || !nzchar(config$label_col)) stop("Set label_col.")
  if (length(config$scope) != 1L || !nzchar(config$scope)) stop("Set the agreed data scope.")
  features <- c(config$numeric_cols, config$binary_cols)
  if (anyDuplicated(features) || config$label_col %in% features) {
    stop("Feature lists must be disjoint and must not contain the label.")
  }
  columns <- c(config$label_col, features)
  if (!all(columns %in% names(data))) {
    stop("Missing columns: ", paste(setdiff(columns, names(data)), collapse = ", "))
  }
  labels <- as.character(data[[config$label_col]])
  if (anyNA(labels) || any(!labels %in% config$expected_labels)) {
    stop("Missing/unexpected labels. Agree label encoding with Tuong; do not silently recode.")
  }
  if (length(config$expected_labels) != 2L || anyNA(config$expected_labels) ||
      anyDuplicated(config$expected_labels)) stop("Expected two distinct labels.")
  for (name in features) {
    x <- data[[name]]
    if (!(is.numeric(x) || is.logical(x))) stop("Non-numeric feature: ", name)
    if (any(!is.finite(x[!is.na(x)]))) stop("Infinite values in: ", name)
  }
  for (name in config$binary_cols) {
    x <- data[[name]]
    if (any(!is.na(x) & !(x %in% c(0, 1)))) stop("Not binary 0/1/NA: ", name)
  }
  if (!all(config$plot_numeric_cols %in% config$numeric_cols) ||
      !all(config$plot_binary_cols %in% config$binary_cols)) {
    stop("Plot columns must belong to the corresponding feature lists.")
  }
  invisible(TRUE)
}

summarize_labels <- function(data, label_col, labels = c("ad", "nonad")) {
  counts <- as.integer(table(factor(data[[label_col]], levels = labels)))
  data.frame(class = labels, n = counts, proportion = counts / nrow(data))
}

numeric_summary_one <- function(x, variable, group) {
  valid <- x[!is.na(x)]
  n <- length(valid)
  quartiles <- if (n) as.numeric(quantile(valid, c(.25, .5, .75), type = 7)) else rep(NA_real_, 3)
  data.frame(variable = variable, group = group, n_total = length(x), n_valid = n,
             n_missing = sum(is.na(x)), mean = if (n) mean(valid) else NA_real_,
             sd = if (n > 1L) sd(valid) else NA_real_,
             min = if (n) min(valid) else NA_real_, q1 = quartiles[1],
             median = quartiles[2], q3 = quartiles[3],
             max = if (n) max(valid) else NA_real_, iqr = quartiles[3] - quartiles[1])
}

summarize_numeric <- function(data, columns, label_col = NULL, labels = c("ad", "nonad")) {
  rows <- list()
  for (name in columns) {
    rows[[length(rows) + 1L]] <- numeric_summary_one(data[[name]], name, "all")
    if (!is.null(label_col)) for (label in labels) {
      rows[[length(rows) + 1L]] <- numeric_summary_one(
        data[[name]][as.character(data[[label_col]]) == label], name, label)
    }
  }
  if (!length(rows)) return(numeric_summary_one(numeric(), "", "")[FALSE, ])
  do.call(rbind, rows)
}

summarize_binary <- function(data, columns, label_col, labels = c("ad", "nonad")) {
  rows <- list()
  for (name in columns) for (group in c("all", labels)) {
    x <- if (group == "all") data[[name]] else data[[name]][as.character(data[[label_col]]) == group]
    n_valid <- sum(!is.na(x))
    rows[[length(rows) + 1L]] <- data.frame(
      variable = name, group = group, n_total = length(x), n_valid = n_valid,
      n_missing = sum(is.na(x)), n_one = sum(x == 1, na.rm = TRUE),
      proportion_one = if (n_valid) sum(x == 1, na.rm = TRUE) / n_valid else NA_real_)
  }
  if (!length(rows)) return(data.frame(variable = character(), group = character(),
    n_total = integer(), n_valid = integer(), n_missing = integer(), n_one = integer(),
    proportion_one = numeric()))
  do.call(rbind, rows)
}

write_eda_png <- function(path, draw) {
  png(path, width = 1400, height = 900, res = 150)
  on.exit(dev.off(), add = TRUE)
  par(mar = c(6, 5, 4, 2))
  draw()
}

plot_eda_numeric <- function(data, variable, label_col, labels, path) {
  write_eda_png(path, function() {
    par(mfrow = c(1, 2))
    x <- as.numeric(data[[variable]])
    valid <- x[!is.na(x)]
    if (!length(valid)) {
      plot.new(); text(.5, .5, "No observed values")
      plot.new(); text(.5, .5, "No observed values")
    } else {
      hist(valid, main = "Observed distribution", xlab = variable,
           col = "#b7dcd6", border = "white")
      boxplot(lapply(labels, function(label) x[as.character(data[[label_col]]) == label]),
              names = labels, main = "By class (missing omitted)", ylab = variable,
              col = c("#b7dcd6", "#efd4a7"))
    }
  })
}

run_eda <- function(config, data = NULL) {
  if (is.null(data)) {
    if (!file.exists(config$input_file)) stop("Processed input file not found: ", config$input_file)
    data <- read.csv(config$input_file, check.names = FALSE, stringsAsFactors = FALSE,
                     na.strings = c("", "NA"))
  }
  validate_eda(data, config)
  tables <- file.path(config$output_dir, "tables")
  figures <- file.path(config$output_dir, "figures")
  dir.create(tables, recursive = TRUE, showWarnings = FALSE)
  dir.create(figures, recursive = TRUE, showWarnings = FALSE)
  labels <- summarize_labels(data, config$label_col, config$expected_labels)
  numeric <- summarize_numeric(data, config$numeric_cols, config$label_col, config$expected_labels)
  binary <- summarize_binary(data, config$binary_cols, config$label_col, config$expected_labels)
  features <- c(config$numeric_cols, config$binary_cols)
  inventory <- data.frame(variable = names(data),
    role = ifelse(names(data) == config$label_col, "label",
      ifelse(names(data) %in% config$numeric_cols, "numeric",
        ifelse(names(data) %in% config$binary_cols, "binary", "not_selected"))),
    n_missing = vapply(data, function(x) sum(is.na(x)), integer(1)))
  outputs <- list(class_counts = labels, numeric_summary = numeric,
                  binary_summary = binary, column_inventory = inventory)
  for (name in names(outputs)) {
    write.csv(outputs[[name]], file.path(tables, paste0(name, ".csv")),
              row.names = FALSE, na = "NA", fileEncoding = "UTF-8")
  }
  write_eda_png(file.path(figures, "class_distribution.png"), function() {
    centers <- barplot(labels$n, names.arg = labels$class, col = c("#549e91", "#ce9650"),
      ylim = c(0, max(labels$n) * 1.2), ylab = "Number of observations", main = "Class distribution")
    text(centers, labels$n, labels = sprintf("%d (%.1f%%)", labels$n, 100 * labels$proportion), pos = 3)
  })
  # Numeric IDs avoid unsafe file names from URL-derived feature names.
  plot_index <- data.frame(variable = character(), file = character())
  for (i in seq_along(config$plot_numeric_cols)) {
    variable <- config$plot_numeric_cols[i]
    filename <- sprintf("numeric_%03d.png", i)
    plot_eda_numeric(data, variable, config$label_col, config$expected_labels, file.path(figures, filename))
    plot_index <- rbind(plot_index, data.frame(variable = variable, file = filename))
  }
  for (i in seq_along(config$plot_binary_cols)) {
    variable <- config$plot_binary_cols[i]
    filename <- sprintf("binary_%03d.png", i)
    rows <- binary[binary$variable == variable & binary$group != "all", ]
    write_eda_png(file.path(figures, filename), function() {
      rates <- rows$proportion_one
      # Missing rates receive a zero-height placeholder explicitly marked NA.
      heights <- ifelse(is.na(rates), 0, rates)
      centers <- barplot(heights, names.arg = rows$group, ylim = c(0, 1.15),
                        col = c("#549e91", "#ce9650"),
                        ylab = "Proportion of 1 among observed values", main = variable)
      text(centers, heights, labels = ifelse(is.na(rates), "NA (no observations)",
        sprintf("%.1f%%; n=%d", 100 * rates, rows$n_valid)), pos = 3)
    })
    plot_index <- rbind(plot_index, data.frame(variable = variable, file = filename))
  }
  write.csv(plot_index, file.path(tables, "figure_index.csv"), row.names = FALSE, fileEncoding = "UTF-8")
  metadata <- c(paste("Scope:", config$scope), paste("Input:", config$input_file),
    paste("Run time (UTC):", format(Sys.time(), tz = "UTC", usetz = TRUE)),
    paste("Input MD5:", if (file.exists(config$input_file)) unname(tools::md5sum(config$input_file)) else "in-memory data"),
    paste("Rows:", nrow(data)), paste("Columns:", ncol(data)),
    paste("Selected features:", length(features)),
    "Missing values are excluded per variable; denominators are recorded.",
    "SD uses n-1; quartiles use R quantile type 7. No imputation or feature selection is performed.",
    "Figure names are mapped to variables in tables/figure_index.csv.", capture.output(sessionInfo()))
  writeLines(metadata, file.path(config$output_dir, "run_metadata.txt"), useBytes = TRUE)
  message("EDA outputs written to ", config$output_dir)
  invisible(outputs)
}

# Descriptive geometry relationships use one common complete-case sample.
write_geometry_relationships <- function(data, config) {
  variables <- config$numeric_cols
  tables <- file.path(config$output_dir, "tables")
  figures <- file.path(config$output_dir, "figures")
  complete <- data[complete.cases(data[, variables, drop = FALSE]), , drop = FALSE]
  correlation <- cor(complete[, variables, drop = FALSE])
  pairs <- which(upper.tri(correlation, diag = TRUE), arr.ind = TRUE)
  result <- data.frame(feature_x = variables[pairs[, 1]],
                       feature_y = variables[pairs[, 2]],
                       n_complete = nrow(complete), pearson_r = correlation[pairs])
  write.csv(result, file.path(tables, "geometry_correlations.csv"), row.names = FALSE)
  write_eda_png(file.path(figures, "geometry_correlations.png"), function() {
    par(mar = c(7, 7, 3, 2))
    image(seq_along(variables), seq_along(variables), correlation,
          zlim = c(-1, 1), col = hcl.colors(101, "Blue-Red 3"), axes = FALSE,
          xlab = "", ylab = "", main = paste("Pearson r; complete n =", nrow(complete)))
    axis(1, seq_along(variables), variables, las = 2)
    axis(2, seq_along(variables), variables, las = 2)
    for (i in seq_along(variables)) for (j in seq_along(variables)) {
      text(i, j, sprintf("%.3f", correlation[i, j]))
    }
  })
  write_eda_png(file.path(figures, "geometry_scatterplots.png"), function() {
    colors <- c("#28786d", "#a76423")
    pairs(complete[, variables, drop = FALSE], pch = 16, cex = .4,
          col = adjustcolor(colors[match(complete[[config$label_col]], config$expected_labels)], .35),
          main = paste("Geometry pairs; complete n =", nrow(complete)))
    par(xpd = NA)
    legend("topright", legend = config$expected_labels, col = colors, pch = 16, cex = .7)
  })
  audit <- do.call(rbind, lapply(c(config$expected_labels, "all"), function(group) {
    rows <- if (group == "all") data else data[data[[config$label_col]] == group, , drop = FALSE]
    do.call(rbind, lapply(variables, function(variable) {
      x <- rows[[variable]]
      x <- x[!is.na(x)]
      q <- quantile(x, c(.25, .75), type = 7, names = FALSE)
      lower <- q[1] - 1.5 * diff(q)
      upper <- q[2] + 1.5 * diff(q)
      count <- sum(x < lower | x > upper)
      data.frame(variable = variable, group = group, n_valid = length(x),
                 lower_fence = lower, upper_fence = upper,
                 n_flagged = count, proportion_flagged = count / length(x))
    }))
  }))
  write.csv(audit, file.path(tables, "outlier_audit.csv"), row.names = FALSE)
}

# ============================================================================
# Helper functions (scripts/inference_metrics.R)
# ============================================================================
# One point per distinct score: tied observations enter together at a threshold.
precision_recall_points <- function(y, score) {
  if (length(y) != length(score) || !length(y) ||
      anyNA(y) || anyNA(score) || any(!is.finite(score)) ||
      any(!y %in% 0:1) || sum(y) == 0)
    stop("PR metrics require finite scores and binary labels with at least one Ad.")
  ord <- order(score, decreasing = TRUE)
  sorted <- score[ord]
  ends <- cumsum(rle(sorted)$lengths)
  tp <- cumsum(y[ord])[ends]
  data.frame(threshold = sorted[ends], recall = tp / sum(y),
             precision = tp / ends)
}

average_precision <- function(y, score) {
  curve <- precision_recall_points(y, score)
  sum(diff(c(0, curve$recall)) * curve$precision)
}

precision_constrained_threshold <- function(y, score, floor) {
  curve <- precision_recall_points(y, score)
  eligible <- which(curve$precision >= floor)
  if (!length(eligible)) return(1)
  curve$threshold[eligible[which.max(curve$recall[eligible])]]
}

# 95% Wilson score interval for a proportion k / n.
wilson_interval <- function(k, n, level = .95) {
  if (n == 0) return(c(NA_real_, NA_real_))
  as.numeric(prop.test(k, n, conf.level = level, correct = FALSE)$conf.int)
}

# Exact McNemar test for two classifiers judged on the same records:
# only the records where exactly one of the two flags is TRUE carry evidence.
exact_mcnemar <- function(first, second) {
  if (length(first) != length(second) || anyNA(first) || anyNA(second))
    stop("McNemar needs two complete logical vectors of equal length.")
  only_first <- sum(first & !second)
  only_second <- sum(!first & second)
  p <- if (only_first + only_second > 0)
    binom.test(only_first, only_first + only_second)$p.value else 1
  data.frame(only_first = only_first, only_second = only_second, p_value = p)
}

# Percentile interval for AP(second) - AP(first) on the same records.
# Ads and non-ads are resampled separately so every replicate keeps the
# observed class counts and always contains positives.
paired_ap_difference <- function(y, first, second, reps = 2000L, level = .95) {
  pos <- which(y == 1); neg <- which(y == 0)
  draws <- replicate(reps, {
    i <- c(sample(pos, replace = TRUE), sample(neg, replace = TRUE))
    average_precision(y[i], second[i]) - average_precision(y[i], first[i])
  })
  alpha <- (1 - level) / 2
  c(estimate = average_precision(y, second) - average_precision(y, first),
    lower = unname(quantile(draws, alpha)), upper = unname(quantile(draws, 1 - alpha)))
}

# ============================================================================
# Stage runner
# ============================================================================
run_stage <- function(label) {
  cat("\n>>> ", label, "\n", sep = "")
}
clear_stage <- function() {
  rm(list = setdiff(ls(envir = globalenv(), all.names = TRUE), .analysis_keep), envir = globalenv())
  invisible(NULL)
}
# Everything defined up to here (helpers, embedded names, runner) is kept between stages.
.analysis_keep <- c(ls(all.names = TRUE), ".analysis_keep")

# ============================================================================
# Stage 1 -- scripts/01_data_setup.R: read, validate, deduplicate, export processed data
# ============================================================================
run_stage("Stage 1/6: data setup")
# scripts/01_data_setup.R | Thieu Tuong - 2550364 | MT2013, HK261
# V2: deduplicate original features + label BEFORE missing-value processing.
# Keep ALL features, observed values, original ratios, and missing values.
# Base R only: Rscript scripts/01_data_setup.R

find_project_root <- function() analysis_root

main <- function() {
  project_root <- find_project_root()
  old_wd <- getwd()
  old_options <- options(digits = 12, scipen = 999)
  on.exit({setwd(old_wd); options(old_options)}, add = TRUE)
  setwd(project_root)
  for (p in c("data/processed", "output/preprocessing")) {
    dir.create(p, recursive = TRUE, showWarnings = FALSE)
  }
  sink("output/preprocessing/execution_log.txt", split = TRUE)
  on.exit(sink(), add = TRUE)
  save_csv <- function(x, filename) {
    write.csv(x, file.path("data/processed", filename), row.names = FALSE,
              na = "NA", fileEncoding = "UTF-8")
  }
  save_duplicate_group_figure <- function(group_size_summary, label_summary) {
    figure_dir <- "output/preprocessing/figures"
    dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)
    figure_file <- file.path(figure_dir, "duplicate_group_audit.png")
    png(figure_file, width = 1800, height = 900, res = 180)
    on.exit(dev.off(), add = TRUE)
    old_par <- par(no.readonly = TRUE)
    on.exit(par(old_par), add = TRUE)
    par(mfrow = c(1, 2), mar = c(5, 5, 4.5, 1))

    group_labels <- as.character(group_size_summary$Group_Size)
    barplot(group_size_summary$Group_Count, names.arg = group_labels,
      col = "#4C78A8", border = NA, las = 2,
      xlab = "Records in an exact duplicate group",
      ylab = "Number of duplicate groups",
      main = "A. Size of duplicate groups")
    mtext(sprintf("%d groups; %d raw records involved",
                  sum(group_size_summary$Group_Count),
                  sum(group_size_summary$Records_In_Groups)),
          side = 3, line = 0.4, cex = 0.8)

    barplot(label_summary$Rows_Removed, names.arg = label_summary$Label,
      col = c("#E45756", "#54A24B"), border = NA,
      ylab = "Redundant rows removed",
      main = "B. Removed rows by class")
    text(seq_along(label_summary$Rows_Removed), label_summary$Rows_Removed,
         labels = label_summary$Rows_Removed, pos = 3, cex = 0.9)
    mtext(sprintf("%d redundant rows removed", sum(label_summary$Rows_Removed)),
          side = 3, line = 0.4, cex = 0.8)
  }
  cat("INTERNET ADVERTISEMENTS - V2: KEEP FEATURES AND MISSINGNESS\n")
  cat("Runtime:", R.version.string, "\n\n")

  # 1. Read original CSV, including header and export index; never rewrite raw.
  raw_path <- "data/raw/add.csv"
  raw_md5 <- unname(tools::md5sum(raw_path))
  raw <- read.csv(raw_path, header = TRUE, check.names = FALSE,
    colClasses = "character", stringsAsFactors = FALSE,
    na.strings = NULL, strip.white = FALSE)
  stopifnot(identical(names(raw), c("", as.character(0:1558))),
    identical(dim(raw), c(3279L, 1560L)),
    identical(raw[[1]], as.character(seq_len(nrow(raw)) - 1L)))
  raw_index <- as.integer(raw[[1]])
  # This is only whitespace normalization, not filling or reducing features.
  original <- as.data.frame(lapply(raw[-1], trimws), stringsAsFactors = FALSE)
  names(original) <- as.character(0:1558)
  stopifnot(all(original[["1558"]] %in% c("ad.", "nonad.")))
  raw_missing <- as.matrix(original[seq_len(1558)]) == "?"

  # 2. Deduplicate ALL 1558 ORIGINAL FEATURES + LABEL, before NA handling.
  # The unique export index is not an image feature and must not be in the key.
  duplicate <- duplicated(original)
  keep <- !duplicate
  retained <- original[keep, , drop = FALSE]
  # Row audit records source indices and decisions, without changing values.
  row_audit <- data.frame(Raw_Index = raw_index,
    Label = original[["1558"]],
    Missing_Any_Original_Feature = as.integer(rowSums(raw_missing) > 0),
    Missing_Three_Size_Features = as.integer(rowSums(raw_missing[, 1:3]) > 0),
    Status = ifelse(duplicate, "removed_duplicate_full_record", "kept"))
  save_csv(row_audit, "row_audit.csv")

  # Audit the exact duplicate groups themselves. The separator cannot occur in
  # this numeric/binary source data, so each key represents all features + label.
  stopifnot(!any(grepl("\r", unlist(original, use.names = FALSE), fixed = TRUE)))
  full_record_key <- do.call(paste, c(original, sep = "\r"))
  key_counts <- table(full_record_key)
  duplicate_keys <- names(key_counts)[key_counts > 1L]
  first_positions <- match(duplicate_keys, full_record_key)
  group_sizes <- as.integer(key_counts[duplicate_keys])
  duplicate_groups <- data.frame(
    Group_ID = sprintf("DG%03d", seq_along(duplicate_keys)),
    Label = original[["1558"]][first_positions],
    Group_Size = group_sizes,
    Rows_Removed = group_sizes - 1L,
    Retained_Raw_Index = raw_index[first_positions],
    Member_Raw_Indices = vapply(duplicate_keys, function(key) {
      paste(raw_index[full_record_key == key], collapse = ";")
    }, character(1)),
    stringsAsFactors = FALSE)
  duplicate_groups <- duplicate_groups[order(-duplicate_groups$Group_Size,
                                               duplicate_groups$Label,
                                               duplicate_groups$Retained_Raw_Index), ]
  rownames(duplicate_groups) <- NULL
  duplicate_groups$Group_ID <- sprintf("DG%03d", seq_len(nrow(duplicate_groups)))
  save_csv(duplicate_groups, "duplicate_group_audit.csv")
  group_size_summary <- as.data.frame(table(Group_Size = duplicate_groups$Group_Size),
                                      stringsAsFactors = FALSE)
  group_size_summary$Group_Size <- as.integer(as.character(group_size_summary$Group_Size))
  group_size_summary <- group_size_summary[order(group_size_summary$Group_Size), ]
  names(group_size_summary)[2] <- "Group_Count"
  group_size_summary$Records_In_Groups <- with(group_size_summary,
    Group_Size * Group_Count)
  group_size_summary$Rows_Removed <- with(group_size_summary,
    (Group_Size - 1L) * Group_Count)
  save_csv(group_size_summary, "duplicate_group_size_summary.csv")
  label_summary <- data.frame(Label = c("ad.", "nonad."),
    Duplicate_Groups = vapply(c("ad.", "nonad."), function(label) {
      sum(duplicate_groups$Label == label)
    }, integer(1)),
    Records_In_Groups = vapply(c("ad.", "nonad."), function(label) {
      sum(duplicate_groups$Group_Size[duplicate_groups$Label == label])
    }, integer(1)),
    Rows_Removed = vapply(c("ad.", "nonad."), function(label) {
      sum(duplicate_groups$Rows_Removed[duplicate_groups$Label == label])
    }, integer(1)))
  save_csv(label_summary, "duplicate_group_label_summary.csv")
  stopifnot(nrow(duplicate_groups) == 277L, sum(duplicate_groups$Rows_Removed) == 856L,
            sum(duplicate_groups$Group_Size) == 1133L,
            identical(sum(duplicate_groups$Rows_Removed), sum(duplicate)))
  save_duplicate_group_figure(group_size_summary, label_summary)
  report_figure_dir <- "report/figures/preprocessing"
  dir.create(report_figure_dir, recursive = TRUE, showWarnings = FALSE)
  if (!file.copy("output/preprocessing/figures/duplicate_group_audit.png",
                 report_figure_dir, overwrite = TRUE)) {
    stop("Could not publish duplicate-group figure to the report.")
  }

  # 3. Convert '?' to R NA, and parse numbers WITHOUT imputing any value.
  parse_number <- function(text) {
    text[text %in% c("?", "")] <- NA_character_
    number <- suppressWarnings(as.numeric(text))
    if (any(!is.na(text) & is.na(number))) stop("Non-numeric feature value.")
    if (any(!is.finite(number[!is.na(number)]))) stop("Non-finite feature.")
    number
  }
  parsed <- as.data.frame(lapply(retained[seq_len(1558)], parse_number),
                          stringsAsFactors = FALSE)
  feature_names <- c("Height", "Width", "Aspect_Ratio", "Local",
                     sprintf("term_%04d", 4:1557))
  names(parsed) <- feature_names
  stopifnot(all(vapply(parsed[4:1558], function(v) {
    all(is.na(v) | v %in% c(0, 1))
  }, logical(1))))
  stopifnot(all(vapply(parsed[1:3], function(v) {
    all(is.na(v) | v > 0)
  }, logical(1))))
  # Keep original observed Aspect_Ratio; DO NOT recalculate Width/Height.
  processed <- data.frame(row_id = raw_index[keep], parsed,
    IsAds = factor(retained[["1558"]], levels = c("ad.", "nonad.")),
    check.names = FALSE)
  # User requested a flag for ANY missing original feature (including Local).
  # This differs from a flag restricted to the first three size features.
  processed$missing_size <- as.integer(rowSums(is.na(parsed)) > 0)
  rownames(processed) <- NULL
  stopifnot(nrow(processed) == 2423L, ncol(processed) == 1561L,
    sum(duplicate) == 856L, sum(processed$IsAds == "ad.") == 386L,
    sum(processed$IsAds == "nonad.") == 2037L,
    !anyDuplicated(processed[c(feature_names, "IsAds")]),
    sum(is.na(processed)) == 1473L, sum(processed$missing_size) == 499L,
    identical(processed$missing_size, as.integer(rowSums(is.na(parsed)) > 0)))
  save_csv(processed, "internet_ads_processed.csv")

  # 4. Export metadata for EVERY output column, not just size features.
  before <- c(0L, as.integer(colSums(raw_missing)), 0L, 0L)
  after <- as.integer(colSums(is.na(processed)))
  roles <- c("identifier", rep("feature", 1558), "target", "derived_flag")
  descriptions <- c("Chỉ mục dòng gốc; giữ để truy vết, không dùng làm biến dự báo",
    "Chiều cao ảnh", "Chiều rộng ảnh", "Tỷ lệ Width/Height gốc, giữ nguyên",
    "Chỉ báo nhị phân Local; giữ giá trị và NA gốc",
    paste0("Đặc trưng nhị phân gốc cột ", 4:1557,
           "; tên gốc UCI ghi trong Original_UCI_Name"),
    "Nhãn: ad. là quảng cáo; nonad. là không quảng cáo",
    "1 nếu bất kỳ đặc trưng gốc nào thiếu, kể cả Local; 0 nếu đủ toàn bộ")
  types <- c("integer", rep("numeric", 1558), "factor", "integer_binary")
  uci_names <- uci_feature_names
  stopifnot(nrow(uci_names) == 1558L,
            identical(uci_names$Raw_Column_Name, as.character(0:1557)),
            !anyNA(uci_names$Original_UCI_Name))
  dictionary <- data.frame(Variable_Name = names(processed),
    Original_UCI_Name = c(NA_character_, uci_names$Original_UCI_Name,
                          NA_character_, NA_character_),
    Raw_Column_Name = c("(blank)", as.character(0:1558), "(derived)"),
    CSV_Column_Position = c(seq_len(1560), NA_integer_), Role = roles,
    Data_Type = types, Unit = c("none", "pixel", "pixel", "dimensionless",
                              rep("none", 1557)),
    Missing_Before = before, Missing_After = after,
    Description = descriptions,
    Processing = c("Giữ chỉ mục; loại khỏi khóa xét trùng",
      rep("Giữ giá trị quan sát; chuyển ? thành NA; không điền khuyết", 1558),
      "Giữ ad./nonad.; quy ước số nếu cần: ad.=1, nonad.=0",
      "Tạo sau loại trùng từ is.na() của toàn bộ 1558 đặc trưng"))
  save_csv(dictionary, "data_dictionary.csv")
  missing_summary <- data.frame(Variable = names(processed),
    Missing_Before = before, Rate_Before = 100 * before / nrow(raw),
    Missing_After = after, Rate_After = 100 * after / nrow(processed))
  save_csv(missing_summary, "missing_summary.csv")
  class_rows <- function(labels, stage) {
    counts <- table(factor(labels, levels = c("ad.", "nonad.")))
    data.frame(Stage = stage, Label = names(counts), Count = as.integer(counts),
               Percent = 100 * as.numeric(counts) / length(labels))
  }
  classes <- rbind(class_rows(original[["1558"]], "raw"),
                    class_rows(processed$IsAds, "processed"))
  save_csv(classes, "class_distribution.csv")
  flag_rows <- function(labels, flag, stage) {
    tab <- as.data.frame(table(missing_size = factor(as.integer(flag), levels = c(0,1)),
                              Label = factor(labels, levels = c("ad.","nonad."))))
    names(tab)[3] <- "Count"
    tab$Stage <- stage
    totals <- ave(tab$Count, tab$missing_size, FUN = sum)
    tab$Percent_Within_Flag <- 100 * tab$Count / totals
    tab[c("Stage", "missing_size", "Label", "Count", "Percent_Within_Flag")]
  }
  flag_table <- rbind(flag_rows(original[["1558"]], rowSums(raw_missing)>0, "raw"),
    flag_rows(processed$IsAds, processed$missing_size, "processed"))
  save_csv(flag_table, "missing_size_distribution.csv")
  describe <- function(v) c(Observed = sum(!is.na(v)), Missing = sum(is.na(v)),
    Mean_Observed = mean(v, na.rm=TRUE), SD_Observed = sd(v, na.rm=TRUE),
    Min = min(v, na.rm=TRUE), Q1 = unname(quantile(v,.25,na.rm=TRUE)),
    Median = median(v,na.rm=TRUE), Q3 = unname(quantile(v,.75,na.rm=TRUE)),
    Max = max(v,na.rm=TRUE))
  stats <- sapply(processed[c("Height","Width","Aspect_Ratio")], describe)
  save_csv(data.frame(Statistic=rownames(stats),stats,row.names=NULL),
           "descriptive_statistics.csv")
  audit <- data.frame(Step = c("raw_csv", "deduplicate_full_record",
    "parse_NA_keep_all_features", "add_missing_size"),
    Rows = c(3279L, nrow(retained), nrow(parsed), nrow(processed)),
    Columns = c(1560L,1560L,1560L,ncol(processed)),
    Rows_Removed = c(0L,sum(duplicate),0L,0L),
    Missing_Cells = c(sum(raw_missing),sum(raw_missing[keep,]),
                       sum(is.na(parsed)),sum(is.na(processed))))
  save_csv(audit, "audit_log.csv")
  conflict_groups <- nrow(unique(original)) - nrow(unique(original[1:1558]))
  size_only_missing <- sum(rowSums(is.na(parsed[1:3])) > 0)
  summary <- data.frame(Metric=c("raw_rows","raw_csv_columns","original_features",
    "duplicate_rows_removed","processed_rows","output_columns","processed_ad",
    "processed_nonad","missing_cells_after","missing_size_rows",
    "missing_three_size_features","conflicting_label_groups"),
    Actual=c(nrow(raw),ncol(raw),1558,sum(duplicate),nrow(processed),ncol(processed),
      sum(processed$IsAds=="ad."),sum(processed$IsAds=="nonad."),
      sum(is.na(processed)),sum(processed$missing_size),size_only_missing,conflict_groups))
  save_csv(summary, "preprocessing_summary.csv")
  metadata <- data.frame(Key=c("version","dataset","source_url","raw_filename",
    "download_date_declared","date_note","run_timestamp","observation_unit",
    "raw_md5","raw_bytes","deduplication_scope","missing_size_definition",
    "missing_policy","label_mapping","R_version"),
    Value=c("v2 - preserve features and missingness","Internet Advertisements",
      "https://www.kaggle.com/datasets/uciml/internet-advertisements-data-set/data",
      "add.csv","2026-11-08","Ngày tải theo hồ sơ sinh viên; chưa xác minh độc lập",
      format(Sys.time(),tz="Asia/Bangkok",format="%Y-%m-%d %H:%M:%S %Z"),
      "Một bản ghi mô tả ảnh trên trang web",raw_md5,as.character(file.info(raw_path)$size),
      "Toàn bộ 1558 đặc trưng + nhãn gốc; không gồm chỉ mục xuất CSV; trước xử lý NA",
      "1 nếu bất kỳ đặc trưng gốc nào thiếu (bao gồm Local); 0 nếu đủ toàn bộ",
      "Giữ NA; không mean/median; không tính lại ratio; không loại thiếu Local",
      "ad.=1; nonad.=0 nếu cần biến số; file giữ nhãn chữ",R.version.string))
  save_csv(metadata,"source_metadata.csv")

  # 5. Report macros, raw integrity, and exported-file checks.
  macros <- c(NRaw=nrow(raw),NFileColumns=ncol(raw),NDuplicatesRemoved=sum(duplicate),
    NDuplicateGroups=nrow(duplicate_groups),
    NRecordsInDuplicateGroups=sum(duplicate_groups$Group_Size),
    NProcessed=nrow(processed),NOutputColumns=ncol(processed),
    NAdsRaw=sum(original[["1558"]]=="ad."),
    NNonadsRaw=sum(original[["1558"]]=="nonad."),
    NAdsProcessed=sum(processed$IsAds=="ad."),
    NNonadsProcessed=sum(processed$IsAds=="nonad."),NMissingFlag=sum(processed$missing_size),
    NSizeMissing=size_only_missing)
  writeLines(c("% Generated from R results; do not edit numeric values.",
    paste0("\\newcommand{\\",names(macros),"}{",sprintf("%.0f",macros),"}")),
    "output/preprocessing/results_generated.tex")
  stopifnot(identical(raw_md5,unname(tools::md5sum(raw_path))))
  exported <- read.csv("data/processed/internet_ads_processed.csv",check.names=FALSE,
                       na.strings="NA",stringsAsFactors=FALSE)
  stopifnot(identical(dim(exported),dim(processed)),
    identical(names(exported),names(processed)),sum(is.na(exported))==1473L,
    identical(exported$row_id,processed$row_id),
    all(vapply(feature_names,function(v) isTRUE(all.equal(exported[[v]],processed[[v]],
      check.attributes=FALSE,tolerance=0.000000000001)),logical(1))))
  cat("Processing stages:\n"); print(audit,row.names=FALSE)
  cat("\nClass distribution:\n"); print(classes,row.names=FALSE)
  cat("\nMissing flag distribution:\n"); print(flag_table,row.names=FALSE)
  cat("\nMissing features:\n"); print(missing_summary[missing_summary$Missing_Before>0,],row.names=FALSE)
  cat("\nSummary:\n"); print(summary,row.names=FALSE)
  cat("\nRaw MD5 unchanged:",raw_md5,"\n")
  cat("SUCCESS: retained all features, NA, original ratios; no imputation.\n\n")
  print(sessionInfo())
  invisible(processed)
}

main()

clear_stage()

# ============================================================================
# Stage 2 -- scripts/02_eda_descriptive.R: descriptive statistics and figures
# ============================================================================
run_stage("Stage 2/6: descriptive statistics")
# Owner: Bach. Run from the repository root with Rscript.
# Input: v2 full-feature processed CSV; no raw-data cleaning here.

eda_config <- list(
  input_file = "data/processed/internet_ads_processed.csv",
  label_col = "IsAds",
  numeric_cols = c("Height", "Width", "Aspect_Ratio"),
  binary_cols = c("Local", "missing_size"),
  plot_numeric_cols = c("Height", "Width", "Aspect_Ratio"),
  plot_binary_cols = c("Local", "missing_size"),
  scope = "V2 full-record deduplicated dataset; missing values retained",
  output_dir = "output/eda-r",
  expected_labels = c("ad.", "nonad.")
)

processed <- read.csv(eda_config$input_file, check.names = FALSE, na.strings = c("", "NA"))
stopifnot("missing_size" %in% names(processed))
run_eda(eda_config, processed)
write_geometry_relationships(processed, eda_config)

write_eda_png(file.path(eda_config$output_dir, "figures", "geometry_qq.png"), function() {
  par(mfrow = c(1, 2))
  for (variable in c("Height", "Width")) {
    observed <- na.omit(processed[[variable]])
    qqnorm(observed, main = paste(variable, "(n =", length(observed), ")"),
           pch = 16, cex = .4)
    qqline(observed, col = "#a76423")
  }
})

# Publish only the complete set of figures from this successful R run.
figure_files <- c("class_distribution.png", sprintf("numeric_%03d.png", 1:3),
                  sprintf("binary_%03d.png", seq_along(eda_config$plot_binary_cols)),
                  "geometry_correlations.png",
                  "geometry_scatterplots.png", "geometry_qq.png")
figure_sources <- file.path(eda_config$output_dir, "figures", figure_files)
if (!all(file.exists(figure_sources))) stop("Incomplete R figure set.")
report_figures <- "report/figures/eda"
dir.create(report_figures, recursive = TRUE, showWarnings = FALSE)
if (!all(file.copy(figure_sources, report_figures, overwrite = TRUE))) {
  stop("Could not publish all R figures to the report.")
}
figure_index <- data.frame(
  variable = c("IsAds", eda_config$numeric_cols, eda_config$plot_binary_cols,
               "geometry_correlation", "geometry_pairs", "geometry_qq"),
  file = figure_files
)
write.csv(figure_index,
          file.path(eda_config$output_dir, "tables", "figure_index.csv"),
          row.names = FALSE)
message("Published ", length(figure_files), " R figures to ", report_figures)

clear_stage()

# ============================================================================
# Stage 3 -- scripts/eda_terms.R: descriptive analysis of the 1,554 term indicators
# ============================================================================
run_stage("Stage 3/6: term indicators")
# Descriptive analysis of the 1,554 binary term indicators.
# Run standalone: Rscript scripts/eda_terms.R
root <- normalizePath(".")
if (!file.exists(file.path(root, "data", "processed", "internet_ads_processed.csv")))
  stop("Run from the repository root.")
original_names <- load_term_names(root)
input <- file.path(root, "data", "processed", "internet_ads_processed.csv")
out <- file.path(root, "output", "eda-r")
table_dir <- file.path(out, "tables")
figure_dir <- file.path(out, "figures")
report_dir <- file.path(root, "report", "figures", "eda")
for (path in c(table_dir, figure_dir, report_dir))
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
data <- read.csv(input, check.names = FALSE, stringsAsFactors = FALSE,
                 na.strings = c("", "NA"))
terms <- grep("^term_[0-9]{4}$", names(data), value = TRUE)
if (length(terms) != 1554L) stop("Expected exactly 1,554 term indicators.")
x <- as.matrix(data[terms])
storage.mode(x) <- "integer"
if (anyNA(x) || any(!x %in% 0:1)) stop("Terms must be complete binary 0/1 values.")
y <- data$IsAds == "ad."
if (anyNA(y) || !all(data$IsAds %in% c("ad.", "nonad."))) stop("Invalid labels.")

support <- colSums(x)
ad_support <- colSums(x[y, , drop = FALSE])
nonad_support <- support - ad_support
n_ad <- sum(y); n_nonad <- sum(!y)
# Identical columns describe the same observed 0/1 pattern, although their
# original feature IDs remain separate in the exported prevalence table.
distinct_patterns <- sum(!duplicated(as.data.frame(t(x))))
eligible_patterns <- sum(!duplicated(as.data.frame(t(x[, support >= 20,
                                                    drop = FALSE]))))
term_table <- data.frame(
  term = terms, name = unname(original_names[terms]), support = support, ad_support = ad_support,
  nonad_support = nonad_support,
  prevalence_all = support / nrow(x),
  prevalence_ad = ad_support / n_ad,
  prevalence_nonad = nonad_support / n_nonad,
  prevalence_difference = ad_support / n_ad - nonad_support / n_nonad,
  ad_rate_when_present = ifelse(support > 0, ad_support / pmax(support, 1), NA_real_),
  row.names = NULL)
write.csv(term_table, file.path(table_dir, "term_prevalence_all.csv"), row.names = FALSE)
write.csv(term_table[c("term", "name")],
          file.path(root, "data", "processed", "term_names.csv"), row.names = FALSE)

row_count <- rowSums(x)
row_table <- data.frame(row_id = data$row_id, IsAds = data$IsAds,
                        active_terms = row_count)
write.csv(row_table, file.path(table_dir, "term_count_per_record.csv"), row.names = FALSE)
overview <- data.frame(
  records = nrow(x), term_columns = ncol(x), active_cells = sum(x),
  density = mean(x), terms_never_present = sum(support == 0),
  terms_present_at_least_20 = sum(support >= 20),
  terms_present_under_20 = sum(support < 20),
  distinct_term_patterns = distinct_patterns,
  distinct_eligible_patterns = eligible_patterns,
  ad_mean_active_terms = mean(row_count[y]),
  nonad_mean_active_terms = mean(row_count[!y]),
  ad_median_active_terms = median(row_count[y]),
  nonad_median_active_terms = median(row_count[!y]))
write.csv(overview, file.path(table_dir, "term_overview.csv"), row.names = FALSE)

# Minimum support avoids ranking terms that appear in only a few records.
eligible <- term_table[term_table$support >= 20, ]
top <- head(eligible[order(-abs(eligible$prevalence_difference),
                           -eligible$support, eligible$term), ], 10)
write.csv(top, file.path(table_dir, "term_top_class_contrasts.csv"), row.names = FALSE)
top_plot <- head(top, 6)

png(file.path(figure_dir, "term_count_by_class.png"),
    width = 1200, height = 750, res = 150)
par(mar = c(5, 5, 4, 2))
boxplot(row_count[y], row_count[!y], names = c("Ad", "Non-Ad"),
        col = c("#D55E00", "#0072B2"), outline = FALSE,
        ylab = "Active terms per record",
        main = "Number of active term indicators by class")
stripchart(list(row_count[y], row_count[!y]), method = "jitter",
           vertical = TRUE, add = TRUE, pch = 16, cex = .28,
           col = adjustcolor("#333333", alpha.f = .18))
dev.off()

png(file.path(figure_dir, "term_class_prevalence.png"),
    width = 1600, height = 1050, res = 160)
par(mar = c(5, 13, 3, 2))
values <- rbind(Ad = 100 * top_plot$prevalence_ad,
                Nonad = 100 * top_plot$prevalence_nonad)
labels <- sprintf("%s (%s)", top_plot$term, top_plot$name)
barplot(values[, nrow(top_plot):1, drop = FALSE], beside = TRUE, horiz = TRUE,
        names.arg = rev(labels), las = 1, cex.names = .85,
        col = c("#D55E00", "#0072B2"), border = NA,
        xlab = "Within-class prevalence (%)",
        main = "Largest term prevalence differences")
legend("bottomright", c("Ad", "Non-Ad"),
       fill = c("#D55E00", "#0072B2"), bty = "n")
dev.off()

files <- c("term_count_by_class.png", "term_class_prevalence.png")
if (!all(file.copy(file.path(figure_dir, files), report_dir, overwrite = TRUE)))
  stop("Could not publish term figures to the report.")
index_path <- file.path(table_dir, "figure_index.csv")
index <- if (file.exists(index_path)) read.csv(index_path, stringsAsFactors = FALSE) else
  data.frame(variable = character(), file = character())
index <- index[!index$file %in% files, c("variable", "file")]
index <- rbind(index, data.frame(variable = c("active_term_count", "term_class_prevalence"),
                                 file = files))
write.csv(index, index_path, row.names = FALSE)
message("Term EDA complete: ", ncol(x), " indicators across ", nrow(x),
        " processed records; 2 report figures published.")

clear_stage()

# ============================================================================
# Stage 4 -- scripts/03_inference_model.R: group split, tests, logistic models
# ============================================================================
run_stage("Stage 4/6: inference models")
root <- analysis_root
out <- file.path(root, "output", "inference")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
term_label <- load_term_names(root)

read <- function(path) {
  d <- read.csv(path, check.names = FALSE, stringsAsFactors = FALSE, na.strings = c("NA", "?", ""))
  stopifnot(all(c("row_id", "Height", "Width", "Aspect_Ratio", "Local", "IsAds", "missing_size") %in% names(d)))
  stopifnot(!anyDuplicated(d$row_id), all(d$IsAds %in% c("ad.", "nonad.")))
  d
}
source_path <- file.path(root, "data", "processed", "internet_ads_processed.csv")
data <- read(source_path)
feature_cols <- setdiff(names(data), c("row_id", "IsAds", "missing_size"))
key <- do.call(paste, c(data[feature_cols], sep = "\r"))
data$group_id <- sprintf("grp_%06d", match(key, unique(key)))
group_rows <- split(seq_len(nrow(data)), data$group_id)
group_ad <- vapply(group_rows, function(i) any(data$IsAds[i] == "ad."), logical(1))
set.seed(42)
test_groups <- unlist(lapply(c(TRUE, FALSE), function(is_ad) {
  candidates <- names(group_ad)[group_ad == is_ad]
  sample(candidates, size = round(.20 * length(candidates)))
}), use.names = FALSE)
data$split <- ifelse(data$group_id %in% test_groups, "test", "train")
train <- data[data$split == "train", ]
stopifnot(!length(intersect(unique(data$group_id[data$split == "train"]),
                            unique(data$group_id[data$split == "test"]))))
manifest <- data.frame(row_id = data$row_id, group_id = data$group_id,
                       split = data$split, IsAds = data$IsAds)
write.csv(manifest, file.path(out, "processed_group_split.csv"), row.names = FALSE)
write.csv(data.frame(source = "data/processed/internet_ads_processed.csv",
                     source_md5 = unname(tools::md5sum(source_path)),
                     seed = 42, train_n = nrow(train), test_n = sum(data$split == "test"),
                     train_ad = sum(train$IsAds == "ad."),
                     test_ad = sum(data$IsAds[data$split == "test"] == "ad."),
                     group_overlap = 0),
          file.path(out, "split_audit.csv"), row.names = FALSE)

tab <- table(Missing = factor(train$missing_size, levels = 0:1),
             Class = factor(train$IsAds, levels = c("ad.", "nonad.")))
stopifnot(all(tab > 0))
chi <- suppressWarnings(chisq.test(tab, correct = FALSE))
if (any(chi$expected < 5)) stop("Chi-square expected count below 5; use an exact test.")
write.csv(as.data.frame.matrix(tab), file.path(out, "missingness_contingency.csv"))
write.csv(data.frame(n = sum(tab), statistic = unname(chi$statistic), df = unname(chi$parameter),
                     p_value = chi$p.value, min_expected = min(chi$expected),
                     cramers_v = sqrt(unname(chi$statistic) / sum(tab)),
                     ad_rate_missing = tab["1", "ad."] / sum(tab["1", ]),
                     ad_rate_observed = tab["0", "ad."] / sum(tab["0", ])),
          file.path(out, "missingness_chisquare.csv"), row.names = FALSE)

# Two-sample comparison of observed widths on training data (Welch t-test).
# Width is right-skewed, but each class has hundreds of observed widths, so
# the sample means are close to normal.
width_ad <- train$Width[train$IsAds == "ad." & !is.na(train$Width)]
width_nonad <- train$Width[train$IsAds == "nonad." & !is.na(train$Width)]
welch <- t.test(width_ad, width_nonad, var.equal = FALSE)
write.csv(data.frame(n_ad = length(width_ad), n_nonad = length(width_nonad),
                     mean_ad = mean(width_ad), mean_nonad = mean(width_nonad),
                     sd_ad = sd(width_ad), sd_nonad = sd(width_nonad),
                     median_ad = median(width_ad), median_nonad = median(width_nonad),
                     difference = mean(width_ad) - mean(width_nonad),
                     lower_95 = welch$conf.int[1], upper_95 = welch$conf.int[2],
                     t = unname(welch$statistic), df = unname(welch$parameter),
                     p_value = welch$p.value),
          file.path(out, "width_welch_test.csv"), row.names = FALSE)

prepare <- function(d, medians) {
  d$Ad <- as.integer(d$IsAds == "ad.")
  for (nm in c("Height", "Width", "Aspect_Ratio")) {
    d[[paste0(nm, "_missing")]] <- as.integer(is.na(d[[nm]]))
    d[[nm]][is.na(d[[nm]])] <- medians[[nm]]
    d[[paste0("log2_", nm)]] <- log2(d[[nm]])
  }
  d$Local_missing <- as.integer(is.na(d$Local))
  d$Local[is.na(d$Local)] <- medians[["Local"]]
  d$Local <- as.numeric(d$Local)
  d$wide_banner <- as.integer(d$Aspect_Ratio >= 6)
  d
}
# The one reference model for both comparisons in Chapter 5:
# geometry shape (fit_pair) and term indicators (fit_term_models).
base_formula <- Ad ~ log2_Height + log2_Width + Local + missing_size
fit_pair <- function(d) {
  med <- vapply(c("Height", "Width", "Aspect_Ratio"), function(nm) median(d[[nm]], na.rm = TRUE), numeric(1))
  med <- c(med, Local = as.numeric(names(which.max(table(d$Local)))))
  x <- prepare(d, med)
  rich_formula <- Ad ~ splines::ns(log2_Height, df = 3) +
    splines::ns(log2_Width, df = 3) + wide_banner +
    log2_Height:log2_Width + Local + missing_size
  fits <- list(main = glm(base_formula, family = binomial(), data = x),
               format_interaction = glm(rich_formula, family = binomial(), data = x))
  if (any(vapply(fits, function(f) !f$converged || anyNA(coef(f)), logical(1))))
    stop("Logistic fit failed to converge or has aliased coefficients.")
  list(medians = med, fits = fits)
}
predict_pair <- function(pair, d) {
  x <- prepare(d, pair$medians)
  lapply(pair$fits, function(f) as.numeric(predict(f, newdata = x, type = "response")))
}

groups <- train[!duplicated(train$group_id), c("group_id", "IsAds")]
set.seed(42)
groups$fold <- NA_integer_
for (label in c("ad.", "nonad.")) {
  idx <- which(groups$IsAds == label)
  groups$fold[idx] <- sample(rep(1:5, length.out = length(idx)))
}
fold <- groups$fold[match(train$group_id, groups$group_id)]
stopifnot(!anyNA(fold))
oof <- data.frame(row_id = train$row_id, Ad = as.integer(train$IsAds == "ad."),
                  group_id = train$group_id, fold = fold, main = NA_real_,
                  format_interaction = NA_real_)
for (k in 1:5) {
  pair <- fit_pair(train[fold != k, ])
  pred <- predict_pair(pair, train[fold == k, ])
  for (nm in names(pred)) oof[fold == k, nm] <- pred[[nm]]
}
stopifnot(!anyNA(oof$main), !anyNA(oof$format_interaction))
write.csv(oof, file.path(out, "train_oof_predictions.csv"), row.names = FALSE)
final <- fit_pair(train)
saveRDS(final, file.path(out, "logistic_models.rds"))

s <- summary(final$fits$main)$coefficients
or <- data.frame(term = rownames(s), coefficient = s[, 1], std_error = s[, 2],
                 odds_ratio = exp(s[, 1]), lower_95 = exp(s[, 1] - qnorm(.975) * s[, 2]),
                 upper_95 = exp(s[, 1] + qnorm(.975) * s[, 2]), p_value = s[, 4],
                 row.names = NULL)
write.csv(or, file.path(out, "main_effect_odds_ratios.csv"), row.names = FALSE)
message("Inference complete: ", nrow(train), " train records from data/processed; test labels unused for fitting.")

# Term inference: select on training data and repeat selection inside each
# grouped fold. The existing split and folds above are shared by design.
term_names <- names(term_label)
if (!all(term_names %in% names(data))) stop("Term columns are missing.")
if (anyNA(data[term_names]) || any(!as.matrix(data[term_names]) %in% 0:1))
  stop("Term indicators must be complete binary values.")
select_terms <- function(d, n = 6L) {
  x <- as.matrix(d[term_names])
  ad <- d$IsAds == "ad."
  support <- colSums(x)
  ad_support <- colSums(x[ad, , drop = FALSE])
  difference <- ad_support / sum(ad) - (support - ad_support) / sum(!ad)
  eligible <- which(support >= 20)
  if (length(eligible) < n) stop("Too few supported terms.")
  term_names[head(eligible[order(-abs(difference[eligible]),
                                 -support[eligible], term_names[eligible])], n)]
}
selected_terms <- select_terms(train)
write.csv(data.frame(rank = seq_along(selected_terms), term = selected_terms,
                     name = term_label[selected_terms], row.names = NULL),
          file.path(out, "term_selected_train.csv"), row.names = FALSE)

term_matrix <- as.matrix(train[term_names])
term_ad <- train$IsAds == "ad."
term_support <- colSums(term_matrix)
term_ad_support <- colSums(term_matrix[term_ad, , drop = FALSE])
term_candidates <- which(term_support >= 20)
term_tests <- lapply(term_candidates, function(j) {
  counts <- matrix(c(term_ad_support[j], sum(term_ad) - term_ad_support[j],
                     term_support[j] - term_ad_support[j],
                     sum(!term_ad) - term_support[j] + term_ad_support[j]),
                   nrow = 2, byrow = TRUE)
  expected <- outer(rowSums(counts), colSums(counts)) / sum(counts)
  valid <- min(expected) >= 5
  result <- if (valid) suppressWarnings(chisq.test(counts, correct = FALSE)) else NULL
  data.frame(term = term_names[j], name = unname(term_label[j]), ad_present = counts[1, 1],
             nonad_present = counts[2, 1],
             ad_prevalence = counts[1, 1] / sum(term_ad),
             nonad_prevalence = counts[2, 1] / sum(!term_ad),
             min_expected = min(expected),
             chi_square = if (valid) unname(result$statistic) else NA_real_,
             p_value = if (valid) result$p.value else NA_real_)
})
term_chi <- do.call(rbind, term_tests)
term_chi$bh_p_value <- NA_real_
valid_term_tests <- !is.na(term_chi$p_value)
term_chi$bh_p_value[valid_term_tests] <-
  p.adjust(term_chi$p_value[valid_term_tests], method = "BH")
term_chi$selected <- term_chi$term %in% selected_terms
write.csv(term_chi, file.path(out, "term_chisquare_train.csv"), row.names = FALSE)

prepare_terms <- function(d, medians) {
  d <- prepare(d, medians)
  d
}
fit_term_models <- function(d, chosen) {
  med <- vapply(c("Height", "Width", "Aspect_Ratio"),
                function(nm) median(d[[nm]], na.rm = TRUE), numeric(1))
  med <- c(med, Local = as.numeric(names(which.max(table(d$Local)))))
  x <- prepare_terms(d, med)
  augmented <- reformulate(c(attr(stats::terms(base_formula), "term.labels"), chosen),
                           response = "Ad")
  fits <- list(baseline = glm(base_formula, family = binomial(), data = x),
               with_terms = glm(augmented, family = binomial(), data = x))
  if (any(vapply(fits, function(f) !f$converged || anyNA(coef(f)), logical(1))))
    stop("Term logistic fit did not converge or has aliased coefficients.")
  list(medians = med, fits = fits, selected = chosen)
}
predict_term_models <- function(model, d) {
  x <- prepare_terms(d, model$medians)
  lapply(model$fits, function(f) as.numeric(predict(f, x, type = "response")))
}
term_oof <- data.frame(row_id = train$row_id,
                       Ad = as.integer(train$IsAds == "ad."), fold = fold,
                       baseline = NA_real_, with_terms = NA_real_)
fold_terms <- lapply(1:5, function(k) {
  chosen <- select_terms(train[fold != k, , drop = FALSE])
  model <- fit_term_models(train[fold != k, , drop = FALSE], chosen)
  prediction <- predict_term_models(model, train[fold == k, , drop = FALSE])
  for (nm in names(prediction)) term_oof[fold == k, nm] <<- prediction[[nm]]
  data.frame(fold = k, rank = seq_along(chosen), term = chosen,
             name = unname(term_label[chosen]))
})
if (anyNA(term_oof)) stop("Incomplete term out-of-fold predictions.")
write.csv(do.call(rbind, fold_terms), file.path(out, "term_selected_by_fold.csv"), row.names = FALSE)
write.csv(term_oof, file.path(out, "term_ablation_oof.csv"), row.names = FALSE)
final_terms <- fit_term_models(train, selected_terms)
saveRDS(final_terms, file.path(out, "term_logistic_models.rds"))
joint_terms <- anova(final_terms$fits$baseline, final_terms$fits$with_terms,
                     test = "Chisq")
write.csv(data.frame(df = joint_terms$Df[2],
                     deviance_reduction = joint_terms$Deviance[2],
                     p_value = joint_terms$`Pr(>Chi)`[2]),
          file.path(out, "term_logistic_joint_test.csv"), row.names = FALSE)
term_coefficients <- summary(final_terms$fits$with_terms)$coefficients[
  selected_terms, , drop = FALSE]
write.csv(data.frame(term = selected_terms, name = unname(term_label[selected_terms]),
                     coefficient = term_coefficients[, 1],
                     odds_ratio = exp(term_coefficients[, 1]),
                     lower_95 = exp(term_coefficients[, 1] -
                                      qnorm(.975) * term_coefficients[, 2]),
                     upper_95 = exp(term_coefficients[, 1] +
                                      qnorm(.975) * term_coefficients[, 2]),
                     p_value = term_coefficients[, 4], row.names = NULL),
          file.path(out, "term_adjusted_odds_ratios.csv"), row.names = FALSE)
message("Term models complete: ", paste(selected_terms, collapse = ", "))

clear_stage()

# ============================================================================
# Stage 5 -- scripts/04_evaluation.R: thresholds, held-out evaluation, comparisons
# ============================================================================
run_stage("Stage 5/6: evaluation")
root <- analysis_root
out <- file.path(root, "output", "inference")
arg <- grep("^--min-precision=", commandArgs(TRUE), value = TRUE)
min_precision <- if (length(arg)) as.numeric(sub("^--min-precision=", "", arg[1])) else .70
if (!is.finite(min_precision) || min_precision <= 0 || min_precision > 1) stop("Invalid min precision.")
oof <- read.csv(file.path(out, "train_oof_predictions.csv"))
pair <- readRDS(file.path(out, "logistic_models.rds"))
source_path <- file.path(root, "data", "processed", "internet_ads_processed.csv")
data <- read.csv(source_path,
                 check.names = FALSE, stringsAsFactors = FALSE, na.strings = c("NA", "?", ""))
audit <- read.csv(file.path(out, "split_audit.csv"), stringsAsFactors = FALSE)
if (!identical(unname(tools::md5sum(source_path)), audit$source_md5[1]))
  stop("Processed data changed since training; rerun 03_inference_model.R.")
manifest <- read.csv(file.path(out, "processed_group_split.csv"), stringsAsFactors = FALSE)
idx <- match(as.character(data$row_id), as.character(manifest$row_id))
stopifnot(!anyNA(idx), !anyDuplicated(manifest$row_id))
test <- data[manifest$split[idx] == "test", ]
stopifnot(!length(intersect(unique(oof$group_id), unique(manifest$group_id[idx][manifest$split[idx] == "test"]))))

prepare <- function(d, medians) {
  for (nm in c("Height", "Width", "Aspect_Ratio")) {
    d[[nm]][is.na(d[[nm]])] <- medians[[nm]]
    d[[paste0("log2_", nm)]] <- log2(d[[nm]])
  }
  d$Local[is.na(d$Local)] <- medians[["Local"]]
  d$Local <- as.numeric(d$Local)
  d$wide_banner <- as.integer(d$Aspect_Ratio >= 6)
  d
}
x <- prepare(test, pair$medians)
y <- as.integer(test$IsAds == "ad.")
scores <- lapply(pair$fits, function(f) as.numeric(predict(f, newdata = x, type = "response")))
auc_roc <- function(y, p) {
  (sum(rank(p, ties.method = "average")[y == 1]) - sum(y) * (sum(y) + 1) / 2) /
    (sum(y) * sum(y == 0))
}
metrics <- function(y, p, threshold) {
  pred <- p >= threshold
  tp <- sum(pred & y == 1); fp <- sum(pred & y == 0)
  fn <- sum(!pred & y == 1); tn <- sum(!pred & y == 0)
  precision <- if (tp + fp) tp / (tp + fp) else NA_real_
  recall <- tp / (tp + fn)
  data.frame(threshold = threshold, tp = tp, fp = fp, fn = fn, tn = tn,
             precision = precision, recall = recall,
             f2 = if (is.na(precision) || 4 * precision + recall == 0) NA_real_
                  else 5 * precision * recall / (4 * precision + recall),
             accuracy = (tp + tn) / length(y), average_precision = average_precision(y, p),
             roc_auc = auc_roc(y, p))
}
choose_threshold <- function(y, p, floor) {
  candidates <- sort(unique(p), decreasing = TRUE)
  tp <- cumsum(y[order(-p)]); n_pred <- seq_along(y)
  # Evaluate only ends of tied score blocks.
  ends <- match(candidates, p[order(-p)])
  ends <- c(ends[-1] - 1L, length(y))
  precision <- tp[ends] / ends
  recall <- tp[ends] / sum(y)
  eligible <- which(precision >= floor)
  if (!length(eligible)) return(1)
  candidates[eligible[which.max(recall[eligible])]]
}
chosen <- lapply(names(scores), function(nm) {
  threshold <- choose_threshold(oof$Ad, oof[[nm]], min_precision)
  cbind(model = nm, sample = "train_oof", min_precision = min_precision,
        metrics(oof$Ad, oof[[nm]], threshold))
})
chosen_test <- lapply(seq_along(scores), function(i) {
  nm <- names(scores)[i]
  cbind(model = nm, sample = "test", min_precision = min_precision,
        metrics(y, scores[[nm]], chosen[[i]]$threshold))
})
# 95% Wilson intervals: the test set has only 77 ads, so every rate carries
# sampling error that the point estimate alone hides.
add_intervals <- function(r) {
  p <- t(mapply(wilson_interval, r$tp, r$tp + r$fp))
  q <- t(mapply(wilson_interval, r$tp, r$tp + r$fn))
  cbind(r, precision_lower = p[, 1], precision_upper = p[, 2],
        recall_lower = q[, 1], recall_upper = q[, 2])
}
result <- add_intervals(do.call(rbind, c(chosen, chosen_test)))
write.csv(result, file.path(out, "logistic_evaluation.csv"), row.names = FALSE)
write.csv(data.frame(row_id = test$row_id, Ad = y, main = scores$main,
                     format_interaction = scores$format_interaction),
          file.path(out, "test_predictions.csv"), row.names = FALSE)

term_oof <- read.csv(file.path(out, "term_ablation_oof.csv"), stringsAsFactors = FALSE)
term_pair <- readRDS(file.path(out, "term_logistic_models.rds"))
term_x <- prepare(test, term_pair$medians)
term_scores <- lapply(term_pair$fits, function(f) {
  as.numeric(predict(f, newdata = term_x, type = "response"))
})
names(term_scores) <- c("baseline", "with_terms")

term_chosen <- lapply(names(term_scores), function(nm) {
  threshold <- choose_threshold(term_oof$Ad, term_oof[[nm]], min_precision)
  cbind(model = nm, sample = "train_oof", min_precision = min_precision,
        metrics(term_oof$Ad, term_oof[[nm]], threshold))
})
term_chosen_test <- lapply(seq_along(term_scores), function(i) {
  nm <- names(term_scores)[i]
  cbind(model = nm, sample = "test", min_precision = min_precision,
        metrics(y, term_scores[[nm]], term_chosen[[i]]$threshold))
})
term_result <- add_intervals(do.call(rbind, c(term_chosen, term_chosen_test)))
write.csv(term_result, file.path(out, "term_ablation_evaluation.csv"), row.names = FALSE)
write.csv(data.frame(row_id = test$row_id, Ad = y,
                     baseline = term_scores$baseline,
                     with_terms = term_scores$with_terms),
          file.path(out, "term_ablation_test_predictions.csv"), row.names = FALSE)

# Both comparisons start from the same main-effects model. If the term
# pipeline's baseline ever drifts from it, stop instead of reporting two baselines.
stopifnot(isTRUE(all.equal(term_scores$baseline, scores$main)),
          isTRUE(all.equal(term_oof$baseline, oof$main[match(term_oof$row_id, oof$row_id)])),
          isTRUE(all.equal(term_chosen[[1]]$threshold, chosen[[1]]$threshold)))

# Paired comparisons on the same 485 test records: exact McNemar tests for
# ads caught and non-ads flagged, and a bootstrap interval for the AP gain.
comparison_test <- function(comparison, s1, t1, s2, t2) {
  ads <- y == 1
  caught <- exact_mcnemar(s1[ads] >= t1, s2[ads] >= t2)
  flagged <- exact_mcnemar(s1[!ads] >= t1, s2[!ads] >= t2)
  ap <- paired_ap_difference(y, s1, s2)
  data.frame(comparison = comparison,
             ads_caught_only_first = caught$only_first,
             ads_caught_only_second = caught$only_second,
             ads_p_value = caught$p_value,
             nonads_flagged_only_first = flagged$only_first,
             nonads_flagged_only_second = flagged$only_second,
             nonads_p_value = flagged$p_value,
             ap_difference = ap[["estimate"]],
             ap_difference_lower = ap[["lower"]],
             ap_difference_upper = ap[["upper"]])
}
set.seed(2026)
comparisons <- rbind(
  comparison_test("format_interaction_vs_main", scores$main, chosen[[1]]$threshold,
                  scores$format_interaction, chosen[[2]]$threshold),
  comparison_test("with_terms_vs_main", term_scores$baseline, term_chosen[[1]]$threshold,
                  term_scores$with_terms, term_chosen[[2]]$threshold))
write.csv(comparisons, file.path(out, "model_comparison_tests.csv"), row.names = FALSE)
message("Held-out evaluation complete: ", length(y), " test records.")

clear_stage()

# ============================================================================
# Stage 6 -- scripts/05_inference_visuals.R: inference tables and figures
# ============================================================================
run_stage("Stage 6/6: inference figures")
# Tables and figures from the processed-data inference pipeline.
# Run after 03_inference_model.R and 04_evaluation.R:
# Rscript scripts/05_inference_visuals.R
root <- analysis_root
out <- file.path(root, "output", "inference")
figure_dir <- file.path(out, "figures")
table_dir <- file.path(out, "tables")
dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)

read_result <- function(name) {
  path <- file.path(out, name)
  if (!file.exists(path)) stop("Missing ", path, "; run scripts 03 and 04 first.")
  read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
}
audit <- read_result("split_audit.csv")
source_path <- file.path(root, "data", "processed", "internet_ads_processed.csv")
if (!identical(unname(tools::md5sum(source_path)), audit$source_md5[1]))
  stop("Processed data changed; rerun scripts 03 and 04.")
chi <- read_result("missingness_chisquare.csv")
counts <- read_result("missingness_contingency.csv")
or <- read_result("main_effect_odds_ratios.csv")
evaluation <- read_result("logistic_evaluation.csv")
train <- read_result("train_oof_predictions.csv")
test <- read_result("test_predictions.csv")
term_evaluation <- read_result("term_ablation_evaluation.csv")
term_train <- read_result("term_ablation_oof.csv")
term_test <- read_result("term_ablation_test_predictions.csv")
stopifnot(nrow(train) == audit$train_n, nrow(test) == audit$test_n,
          nrow(term_train) == audit$train_n, nrow(term_test) == audit$test_n,
          setequal(term_train$row_id, train$row_id),
          setequal(term_test$row_id, test$row_id),
          all(c("main", "format_interaction", "Ad") %in% names(train)),
          all(c("main", "format_interaction", "Ad") %in% names(test)),
          all(evaluation$sample %in% c("train_oof", "test")))

draw_png <- function(name, width, height, plot_fn) {
  png(file.path(figure_dir, name), width = width, height = height, res = 150)
  tryCatch(plot_fn(), finally = dev.off())
}

# Q1: show conditional class rates with denominators alongside the test table.
missing_table <- data.frame(
  missingness = c("No missing original feature", "At least one missing feature"),
  ad = as.integer(counts[["ad."]]),
  nonad = as.integer(counts[["nonad."]]))
missing_table$total <- missing_table$ad + missing_table$nonad
missing_table$ad_rate <- missing_table$ad / missing_table$total
missing_table$chi_square <- chi$statistic[1]
missing_table$p_value <- chi$p_value[1]
write.csv(missing_table, file.path(table_dir, "missingness_ad_rates.csv"), row.names = FALSE)
draw_png("missingness_ad_rates.png", 1100, 750, function() {
  par(mar = c(6, 5, 4, 2))
  values <- 100 * missing_table$ad_rate
  at <- barplot(values, names.arg = c("Complete", "Any missing"),
                col = c("#0072B2", "#D55E00"), border = NA,
                ylim = c(0, max(values) * 1.35), ylab = "Ad rate (%)",
                main = "Missingness and advertisement status | train")
  text(at, values, sprintf("%.1f%%\n(n=%d)", values, missing_table$total),
       pos = 3, cex = 1)
  mtext(sprintf("Pearson chi-square p = %.4f; rates are associations, not causal effects",
                chi$p_value[1]), side = 1, line = 4, cex = .85)
})

# Q2: exclude the intercept; a log axis gives multiplicative ORs honest spacing.
or <- or[or$term != "(Intercept)", ]
or$label <- c(log2_Height = "Height doubled", log2_Width = "Width doubled",
              Local = "Local = 1", missing_size = "Any missing")[or$term]
if (anyNA(or$label)) stop("Unrecognized odds-ratio term.")
write.csv(or[c("term", "label", "odds_ratio", "lower_95", "upper_95", "p_value")],
          file.path(table_dir, "adjusted_odds_ratios.csv"), row.names = FALSE)
draw_png("adjusted_odds_ratios.png", 1200, 780, function() {
  par(mar = c(5, 12, 4, 3))
  y <- rev(seq_len(nrow(or)))
  plot(or$odds_ratio, y, log = "x", xlim = range(c(.7, or$lower_95, or$upper_95)) * c(.9, 1.1),
       ylim = c(.5, nrow(or) + .5), yaxt = "n", ylab = "", xlab = "Adjusted odds ratio (log scale)",
       pch = 19, cex = 1.35, col = "#0072B2", main = "Main-effects logistic model | train")
  segments(or$lower_95, y, or$upper_95, y, lwd = 2, col = "#0072B2")
  abline(v = 1, lty = 2, col = "#666666")
  axis(2, at = y, labels = or$label, las = 1)
})

# Q3: one reference model and two extensions of it. The term pipeline's
# baseline equals the main-effects model (checked in 04_evaluation.R), so it
# appears once here.
models <- c(main = "Main effects", format_interaction = "Format + interaction",
            with_terms = "Main effects + six terms")
colors <- c(main = "#0072B2", format_interaction = "#D55E00", with_terms = "#009E73")
comparison <- rbind(evaluation[evaluation$model %in% c("main", "format_interaction"), ],
                    term_evaluation[term_evaluation$model == "with_terms", ])
comparison$label <- models[comparison$model]
write.csv(comparison, file.path(table_dir, "model_comparison.csv"), row.names = FALSE)

scores_for <- function(sample) {
  d <- if (sample == "test") test else train
  terms <- if (sample == "test") term_test else term_train
  terms <- terms[match(d$row_id, terms$row_id), ]
  list(y = d$Ad, main = d$main, format_interaction = d$format_interaction,
       with_terms = terms$with_terms)
}
pr <- do.call(rbind, lapply(c("train_oof", "test"), function(sample) {
  s <- scores_for(sample)
  do.call(rbind, lapply(names(models), function(model) {
    cbind(sample = sample, model = model, precision_recall_points(s$y, s[[model]]))
  }))
}))
write.csv(pr, file.path(table_dir, "precision_recall_points.csv"), row.names = FALSE)
# Step curves match average_precision(): precision is constant between
# recall levels. One shared legend below the panels keeps every curve visible.
draw_png("precision_recall_curves.png", 1600, 860, function() {
  par(mfrow = c(1, 2), mar = c(4.5, 4.5, 3, 1.5), oma = c(3, 0, 0, 0),
      cex.main = 1.25, cex.lab = 1.15, cex.axis = 1.05)
  for (sample in c("train_oof", "test")) {
    n_ads <- sum(scores_for(sample)$y)
    plot(c(0, 1), c(0, 1), type = "n", xlab = "Ad recall", ylab = "Ad precision",
         main = sprintf("%s (%d ads)", if (sample == "test") "Held-out test"
                        else "Training, out-of-fold", n_ads))
    abline(h = unique(comparison$min_precision), lty = 3, col = "#666666")
    for (model in names(models)) {
      d <- pr[pr$sample == sample & pr$model == model, ]
      lines(c(0, d$recall), c(d$precision[1], d$precision), type = "S",
            col = colors[model], lwd = 2)
    }
  }
  par(fig = c(0, 1, 0, 1), oma = c(0, 0, 0, 0), mar = c(0, 0, 0, 0), new = TRUE)
  plot(0, 0, type = "n", bty = "n", xaxt = "n", yaxt = "n", xlab = "", ylab = "")
  legend("bottom", models, col = colors, lwd = 2, horiz = TRUE, bty = "n", cex = 1.05)
})

# The 2 x 2 confusion matrices expose class imbalance better than accuracy.
test_metrics <- comparison[comparison$sample == "test", ]
confusion <- do.call(rbind, lapply(seq_len(nrow(test_metrics)), function(i) {
  r <- test_metrics[i, ]
  data.frame(model = r$model, actual = c("Ad", "Ad", "Non-Ad", "Non-Ad"),
             predicted = c("Ad", "Non-Ad", "Ad", "Non-Ad"),
             count = c(r$tp, r$fn, r$fp, r$tn))
}))
write.csv(confusion, file.path(table_dir, "test_confusion_counts.csv"), row.names = FALSE)
draw_png("test_confusion_matrices.png", 2100, 800, function() {
  par(mfrow = c(1, 3), mar = c(10, 5.5, 4, 2), cex.main = 1.6, cex.lab = 1.4, cex.axis = 1.3)
  for (model in names(models)) {
    r <- test_metrics[test_metrics$model == model, ]
    z <- matrix(c(r$tp, r$fn, r$fp, r$tn), 2, 2, byrow = TRUE)
    plot(c(.5, 2.5), c(.5, 2.5), type = "n", axes = FALSE, xlab = "",
         ylab = "Actual", main = models[model])
    for (row in 1:2) for (col in 1:2) {
      rect(col - .48, 2 - row + .52, col + .48, 2 - row + 1.48,
           col = if (row == col) "#C7E9C0" else "#FDD0A2", border = "white")
      text(col, 3 - row, z[row, col], cex = 2.4)
    }
    axis(1, 1:2, c("Ad", "Non-Ad"))
    axis(2, 2:1, c("Ad", "Non-Ad"), las = 1)
    mtext("Predicted class", side = 1, line = 3, cex = 1.1)
    mtext(sprintf("Precision %.2f [%.2f, %.2f]", r$precision, r$precision_lower,
                  r$precision_upper), side = 1, line = 5.4, cex = 1.15)
    mtext(sprintf("Recall %.2f [%.2f, %.2f]", r$recall, r$recall_lower, r$recall_upper),
          side = 1, line = 7.2, cex = 1.15)
  }
})

figure_files <- c("missingness_ad_rates.png", "adjusted_odds_ratios.png",
                  "precision_recall_curves.png", "test_confusion_matrices.png")
report_dir <- file.path(root, "report", "figures", "inference")
dir.create(report_dir, recursive = TRUE, showWarnings = FALSE)
if (!all(file.copy(file.path(figure_dir, figure_files), report_dir,
                   overwrite = TRUE))) stop("Could not publish inference figures.")
message("Created and published ", length(figure_files), " inference figures; wrote 5 CSV tables.")

clear_stage()
cat("\nDone.\n")
