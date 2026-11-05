src=open(__file__.replace('rally_tune.py','rally_model.py')).read().split("old=dict")[0]
src=src.replace("ch=clamp(skill['base']-sped*skill['fade'],0.12,0.98)","ch=clamp(skill['base']-max(0,sped)**2*skill['fade'],0.12,0.99)")
exec(src)
new=dict(startTravel=1.7,speedUp=0.9,perfectSpeedUp=0.84,minTravel=0.42,windowFrac=0.5,windowMin=0.24,windowMax=0.5,
         perfectEarly=0.07,perfectLate=0.12,grace=0.18,whiffLock=0.15,mashSway=0.3,swayNorm=8,botEff=True)
sk={'Easy':dict(base=0.97,fade=0.95,perfect=0.1),'Bronze':dict(base=0.98,fade=0.55,perfect=0.2),'Silver':dict(base=0.99,fade=0.33,perfect=0.3),
    'Gold':dict(base=0.99,fade=0.27,perfect=0.4),'Diamond':dict(base=0.99,fade=0.22,perfect=0.5)}
cps={'Easy':2.5,'Bronze':4,'Silver':5,'Gold':6,'Diamond':7.2}
for tier in sk:
    for hname,h in [('avg-nomash',dict(lag=0.07,sd=0.07,cps=0,mash=False)),('avg-mash7',dict(lag=0.07,sd=0.08,cps=7,mash=True)),('good-mash10',dict(lag=0.04,sd=0.05,cps=10,mash=True)),('weak-nomash',dict(lag=0.12,sd=0.1,cps=0,mash=False))]:
      w,hh,tl=run(new,sk[tier],h,cps[tier],n=3000)
      print(f"{tier:7} {hname:12} win={w:.2f} hits/round={hh:.1f} round_s={tl:.1f}")
