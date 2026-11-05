import random, sys
def clamp(x,a,b): return max(a,min(b,x))
def run(cfg, skill, human, botcps, n=20000, seed=1):
    rnd=random.Random(seed)
    wins=0; hits_total=0; rally_len=0; rounds=0
    for _ in range(n):
        score=[0,0]; to=rnd.choice([0,1])  # 0=human
        while max(score)<2:
            travel=cfg['startTravel']*1.8; prog=0.5; hits=0; t=0
            loser=None
            while loser is None:
                # rate
                hc = human['cps'] if human['mash'] else 0
                recv_cps = hc if to==0 else botcps
                send_cps = botcps if to==0 else hc
                sway = clamp((send_cps-recv_cps)/cfg['swayNorm'],-1,1)*cfg['mashSway']
                rate=(1+sway)/travel
                time_left=(1-prog)/rate; t+=time_left
                window=clamp(travel*cfg['windowFrac'],cfg['windowMin'],cfg['windowMax'])
                if to==0:
                    # human presses at arrival + lag + noise (positive=late)
                    err = human['lag'] + rnd.gauss(0, human['sd'] * (1 + 0.6*clamp((0.9-1/rate)/0.6,0,1)))
                    rem=-err
                    if rem>window:
                        # whiff; maybe can retry if lock allows
                        if rem-cfg['whiffLock']>-cfg['grace'] and rnd.random()<0.6:
                            rem=rnd.uniform(-cfg['grace']*1.5, min(window, rem-cfg['whiffLock']))
                        else: loser=0; break
                    if rem< -cfg['grace']: loser=0; break
                    j='P' if (-cfg['perfectLate']<=rem<=cfg['perfectEarly']) else 'G'
                else:
                    eff = 1/rate if cfg['botEff'] else travel
                    sped=cfg['startTravel']-eff
                    ch=clamp(skill['base']-sped*skill['fade'],0.12,0.98)
                    if rnd.random()<ch: j='P' if rnd.random()<skill['perfect'] else 'G'
                    else: loser=1; break
                base=min(travel,cfg['startTravel'])
                travel=max(cfg['minTravel'], base*(cfg['perfectSpeedUp'] if j=='P' else cfg['speedUp']))
                prog=0; to=1-to; hits+=1
            score[1-loser]+=1; rounds+=1; hits_total+=hits; rally_len+=t
            to = 1-loser  # serve toward round winner
        wins += score[0]==2
    return wins/n, hits_total/rounds, rally_len/rounds

old=dict(startTravel=1.7,speedUp=0.87,perfectSpeedUp=0.8,minTravel=0.3,windowFrac=0.42,windowMin=0.15,windowMax=0.45,
         perfectEarly=0.085,perfectLate=0.085,grace=0.07,whiffLock=0.35,mashSway=0.35,swayNorm=14,botEff=False)
new=dict(startTravel=1.7,speedUp=0.9,perfectSpeedUp=0.84,minTravel=0.42,windowFrac=0.5,windowMin=0.24,windowMax=0.5,
         perfectEarly=0.07,perfectLate=0.11,grace=0.16,whiffLock=0.15,mashSway=0.55,swayNorm=8,botEff=True)
skills={'Easy':dict(base=0.85,fade=0.62,perfect=0.12),'Bronze':dict(base=0.92,fade=0.47,perfect=0.22),
        'Gold':dict(base=0.97,fade=0.34,perfect=0.42)}
newskills={'Easy':dict(base=0.8,fade=0.75,perfect=0.1),'Bronze':dict(base=0.88,fade=0.6,perfect=0.2),
           'Gold':dict(base=0.95,fade=0.45,perfect=0.4)}
cps={'Easy':3.7,'Bronze':6,'Gold':9}
newcps={'Easy':2.5,'Bronze':4,'Gold':6.5}
for label,cfg,sk,bc in [('OLD',old,skills,cps),('NEW',new,newskills,newcps)]:
  for tier in ['Easy','Bronze','Gold']:
    for hname,h in [('avg-nomash',dict(lag=0.07,sd=0.07,cps=0,mash=False)),('avg-mash8',dict(lag=0.07,sd=0.08,cps=8,mash=True)),('good-mash10',dict(lag=0.04,sd=0.05,cps=10,mash=True))]:
      w,hh,tl=run(cfg,sk[tier],h,bc[tier],n=4000)
      print(f"{label} {tier:6} {hname:12} win={w:.2f} hits/round={hh:.1f} round_s={tl:.1f}")
