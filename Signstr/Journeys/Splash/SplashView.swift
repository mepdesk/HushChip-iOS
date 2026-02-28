// Copyright (c) 2026 Gridmark Technologies Ltd (Signstr)
// Licensed under GPL-3.0

import SwiftUI
import WebKit

// MARK: - WKWebView wrapper for the splash animation

private struct SplashWebView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.suppressesIncrementalRendering = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        webView.loadHTMLString(SplashHTML.content, baseURL: nil)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

// MARK: - Splash screen

struct SplashView: View {
    var body: some View {
        ZStack {
            Color(hex: "#09090b").ignoresSafeArea()
            SplashWebView()
                .ignoresSafeArea()
        }
    }
}

// MARK: - Embedded HTML animation

private enum SplashHTML {
    static let content = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width,initial-scale=1.0,user-scalable=no">
    <style>
      *{margin:0;padding:0;box-sizing:border-box}
      body{
        background:#09090b;
        min-height:100vh;
        display:flex;
        flex-direction:column;
        align-items:center;
        justify-content:center;
        font-family:'Outfit',system-ui,sans-serif;
        overflow:hidden;
      }
      @font-face{
        font-family:'Outfit';
        src:url('https://fonts.gstatic.com/s/outfit/v11/QGYyz_MVcBeNP4NjuGObqx1XmO1I4e81O4S.woff2') format('woff2');
        font-weight:200;
        font-style:normal;
      }
      @font-face{
        font-family:'Outfit';
        src:url('https://fonts.gstatic.com/s/outfit/v11/QGYyz_MVcBeNP4NjuGObqx1XmO1I4bF1O4S.woff2') format('woff2');
        font-weight:300;
        font-style:normal;
      }

      .content{
        display:flex;flex-direction:column;align-items:center;
        justify-content:center;width:100%;height:100vh;
        position:relative;
      }
      .brand-block{
        display:flex;flex-direction:column;align-items:center;
        margin-bottom:20px;
      }
      .brand-wordmark{
        font-family:'Outfit',sans-serif;
        font-weight:200;
        font-size:38px;
        letter-spacing:14px;
        text-transform:uppercase;
        color:#cdcdd6;
        margin-bottom:14px;
      }
      .brand-dot{
        letter-spacing:0;
        margin-left:-8px;
      }
      .brand-tagline{
        font-family:'Outfit',sans-serif;
        font-weight:300;
        font-size:10.5px;
        letter-spacing:0.4px;
        color:#5a5a64;
        text-align:center;
        line-height:1.6;
      }
      .anim-wrap{
        width:100%;
        height:180px;
        position:relative;
        display:flex;align-items:center;justify-content:center;
      }
      .anim-wrap canvas{
        position:absolute;top:0;left:50%;transform:translateX(-50%);
        width:100%;max-width:580px;height:100%;
      }
      #pc{z-index:0}#ic{z-index:1}#sc{z-index:2}
    </style>
    </head>
    <body>
    <div class="content">
      <div class="brand-block">
        <div class="brand-wordmark">Signstr<span class="brand-dot">.</span></div>
        <div class="brand-tagline">your keys. your identity.</div>
      </div>
      <div class="anim-wrap">
        <canvas id="pc"></canvas>
        <canvas id="ic"></canvas>
        <canvas id="sc"></canvas>
      </div>
    </div>

    <script>
    (function(){
      'use strict';

      var W=580,H=360;
      var ids=['pc','ic','sc'];
      var cx={};
      for(var ci2=0;ci2<ids.length;ci2++){
        var cv=document.getElementById(ids[ci2]);
        cv.width=W;cv.height=H;
        cx[ids[ci2]]=cv.getContext('2d');
      }
      var paperCtx=cx.pc,inkCtx=cx.ic,sheenCtx=cx.sc;

      (function(){
        paperCtx.fillStyle='#09090b';paperCtx.fillRect(0,0,W,H);
        var img=paperCtx.getImageData(0,0,W,H),d=img.data;
        for(var i=0;i<d.length;i+=4){var n=(Math.random()-0.5)*2.5;d[i]+=n;d[i+1]+=n;d[i+2]+=n;}
        paperCtx.putImageData(img,0,0);

        var lineY=Math.round(25.5*5.2+81);
        var lineX1=W*0.18;
        var lineX2=W*0.82;
        paperCtx.strokeStyle='rgba(255,255,255,0.10)';
        paperCtx.lineWidth=1;
        paperCtx.lineCap='round';
        var dashLen=8,gapLen=6,x=lineX1;
        while(x<lineX2){
          var end=Math.min(x+dashLen,lineX2);
          paperCtx.beginPath();paperCtx.moveTo(x,lineY);paperCtx.lineTo(end,lineY);paperCtx.stroke();
          x=end+gapLen;
        }
      })();

      var SC=5.2,OX=121,OY=81;
      var mainSegs=[
        [[21,8],[19,7],[16.5,7],[14.5,8]],
        [[14.5,8],[11.5,9.5],[10,12],[10.5,14.5]],
        [[10.5,14.5],[11,16.5],[13.5,17.5],[16.5,17.5]],
        [[16.5,17.5],[19.5,17.5],[22.5,18.5],[22.5,21]],
        [[22.5,21],[22.5,23.5],[19.5,25.5],[16.5,26]],
        [[16.5,26],[14.5,26.5],[13,25.5],[14,24]],
        [[14,24],[15.5,22.5],[18,21.5],[20,21.5]],
        [[20,21.5],[22,21.5],[23.5,22],[24,23]],
        [[24,23],[24.5,24],[25,24.2],[25.5,23.5]],
        [[25.5,23.5],[26.5,22.5],[28,22.5],[29,23.5]],
        [[29,23.5],[30,24.5],[30,27],[29.5,29]],
        [[29.5,29],[29,31],[27,31],[27,29]],
        [[27,29],[27,27.5],[29,25.5],[31,24]],
        [[31,24],[32,23],[33.5,22.5],[34.5,23.5]],
        [[34.5,23.5],[35,24.5],[35.5,24],[36,23.5]],
        [[36,23.5],[36.5,23],[38,21.5],[39,21.5]],
        [[39,21.5],[40,21.5],[39.5,23.2],[38.2,23.8]],
        [[38.2,23.8],[37.2,24.2],[39.2,24.5],[40,23.5]],
        [[40,23.5],[40.2,22.2],[40.8,20.5],[41,19.5]],
        [[41,19.5],[41.2,19],[41.5,19.2],[41.5,20]],
        [[41.5,20],[41.5,21.5],[42,23.5],[42.5,24.5]],
        [[42.5,24.5],[43,23.5],[43.5,22.5],[44.2,22.2]],
        [[44.2,22.2],[45,22],[45.8,22.3],[46.5,23]],
        [[46.5,23],[48,23.5],[50.5,23],[53,22.5]]
      ];
      var S_BODY_END=7;

      function cubicPt(a,b,c,d,t){var m=1-t;return[m*m*m*a[0]+3*m*m*t*b[0]+3*m*t*t*c[0]+t*t*t*d[0],m*m*m*a[1]+3*m*m*t*b[1]+3*m*t*t*c[1]+t*t*t*d[1]];}
      var ST=60;
      function buildPath(segs){
        var pts=[];
        for(var s=0;s<segs.length;s++){
          var sg=segs[s],p0=[sg[0][0]*SC+OX,sg[0][1]*SC+OY],p1=[sg[1][0]*SC+OX,sg[1][1]*SC+OY],
            p2=[sg[2][0]*SC+OX,sg[2][1]*SC+OY],p3=[sg[3][0]*SC+OX,sg[3][1]*SC+OY];
          for(var i=(s?1:0);i<=ST;i++) pts.push(cubicPt(p0,p1,p2,p3,i/ST));
        }
        return pts;
      }
      var mainPath=buildPath(mainSegs);
      var mainTotal=mainPath.length;
      var sBodyEnd=S_BODY_END*ST;

      var tCrossStart=[39*SC+OX,20.5*SC+OY];
      var tCrossEnd=[43.5*SC+OX,19.8*SC+OY];
      var tCrossPath=[];
      for(var tc=0;tc<=20;tc++){var tt2=tc/20;tCrossPath.push([tCrossStart[0]+(tCrossEnd[0]-tCrossStart[0])*tt2,tCrossStart[1]+(tCrossEnd[1]-tCrossStart[1])*tt2]);}

      var iDotPos=[25.5*SC+OX,19.5*SC+OY];
      var fullStopPos=[55*SC+OX,23*SC+OY];

      function getDir(pts,i){var p=Math.max(0,i-1),n=Math.min(pts.length-1,i+1);return Math.atan2(pts[n][1]-pts[p][1],pts[n][0]-pts[p][0]);}

      var BW=1,MW=5;
      function flexP(pts,i){var d=Math.sin(getDir(pts,i)),f=Math.max(0,d);return f*f*0.75+0.08;}
      function mainPressure(i){
        var t=i/(mainTotal-1);
        if(t<0.015)return 0.15+(t/0.015)*0.7;
        var sT=sBodyEnd/mainTotal;
        if(t<sT)return 0.95;
        var after=(t-sT)/(1-sT);
        var gBump=0;
        if(after>0.12&&after<0.42){gBump=Math.sin((after-0.12)/0.3*Math.PI)*0.2;}
        return Math.max(0.03,0.7*(1-after*0.85)+gBump);
      }
      function mainSW(i){return Math.max(0.05,BW+(MW-BW)*flexP(mainPath,i)*mainPressure(i));}
      function tCrossW(i){var t=i/20;return (0.8*Math.min(1,t<0.1?t/0.1:1)*Math.min(1,t>0.8?(1-t)/0.2:1))+0.25;}

      var prevIW=BW;
      function drawInk(ctx,pts,i,wFunc){
        if(i<1)return;
        var x0=pts[i-1][0],y0=pts[i-1][1],x1=pts[i][0],y1=pts[i][1];
        var d=getDir(pts,i),w=wFunc(i);
        w=prevIW*0.5+w*0.5;prevIW=w;if(w<0.04)return;
        var px=Math.cos(d+Math.PI/2),py=Math.sin(d+Math.PI/2);
        ctx.beginPath();ctx.moveTo(x0+px*w/2,y0+py*w/2);ctx.lineTo(x1+px*w/2,y1+py*w/2);
        ctx.lineTo(x1-px*w/2,y1-py*w/2);ctx.lineTo(x0-px*w/2,y0-py*w/2);
        ctx.closePath();ctx.fillStyle='rgba(185,185,195,0.92)';ctx.fill();
        ctx.beginPath();ctx.arc(x1,y1,w/2,0,Math.PI*2);ctx.fill();
        if(w>1.8){ctx.beginPath();ctx.arc(x1,y1,w/2+0.2,0,Math.PI*2);ctx.strokeStyle='rgba(160,160,172,0.06)';ctx.lineWidth=0.3;ctx.stroke();}
      }
      function drawDot(ctx,x,y,r){
        ctx.beginPath();ctx.arc(x,y,r,0,Math.PI*2);ctx.fillStyle='rgba(185,185,195,0.92)';ctx.fill();
      }

      var sheenPts=[];
      function addSh(x,y,w){sheenPts.push({x:x,y:y,w:w,b:performance.now()});}
      function drawSh(now){
        sheenCtx.clearRect(0,0,W,H);var alive=[];
        for(var i=0;i<sheenPts.length;i++){var p=sheenPts[i],age=now-p.b;
          if(age<3000){var t2=age/3000;sheenCtx.beginPath();sheenCtx.arc(p.x-0.3,p.y-0.3,p.w/2*0.4,0,Math.PI*2);
            sheenCtx.fillStyle='rgba(220,220,235,'+((1-t2*t2)*0.02)+')';sheenCtx.fill();alive.push(p);}}
        sheenPts=alive;
      }

      // Single cycle -- no looping
      var T_FWD=1200,T_FGAP1=280,T_FIDOT=15,T_FGAP2=80,T_FTCROSS=55,T_FGAP3=350,T_FSTOP=15;
      var T_HOLD=600;
      var T_WRITE=T_FWD+T_FGAP1+T_FIDOT+T_FGAP2+T_FTCROSS+T_FGAP3+T_FSTOP;

      function ss(t){return t*t*(3-2*t);}
      function signEase(t){
        if(t<0.01)return t*t/0.01;
        var sT=sBodyEnd/mainTotal;
        if(t<=sT){var st=(t-0.01)/(sT-0.01);return 0.01+(sT-0.01)*Math.min(ss(st)+Math.sin(st*Math.PI)*0.02,1);}
        var at=(t-sT)/(1-sT);
        var mapped=at+Math.sin(at*Math.PI*4)*0.012;
        if(at>0.9){var et=(at-0.9)/0.1;mapped=0.9+0.1*(et*(2-et));}
        return sT+(1-sT)*Math.min(Math.max(mapped,0),1);
      }

      var anim=null,start=0,mainIdx=0,tCrossIdx=0;
      var dotDone=false,crossDone=false,stopDone=false;

      function animate(ts){
        if(!start)start=ts;
        var el=ts-start;
        var now=performance.now();
        drawSh(now);

        // FORWARD (write phase)
        if(el<T_WRITE){
          var wt=el;
          if(wt<T_FWD){
            var lt=wt/T_FWD;
            var et2=signEase(lt),ti=Math.floor(et2*(mainTotal-1));
            while(mainIdx<=ti&&mainIdx<mainTotal){
              drawInk(inkCtx,mainPath,mainIdx,mainSW);
              var sw2=mainSW(mainIdx);if(sw2>0.15)addSh(mainPath[mainIdx][0],mainPath[mainIdx][1],sw2);
              mainIdx++;
            }
            anim=requestAnimationFrame(animate);return;
          }
          wt-=T_FWD;
          if(wt<T_FGAP1){anim=requestAnimationFrame(animate);return;}
          wt-=T_FGAP1;
          if(wt<T_FIDOT){
            if(!dotDone){drawDot(inkCtx,iDotPos[0],iDotPos[1],1);addSh(iDotPos[0],iDotPos[1],2);dotDone=true;}
            anim=requestAnimationFrame(animate);return;
          }
          wt-=T_FIDOT;
          if(wt<T_FGAP2){anim=requestAnimationFrame(animate);return;}
          wt-=T_FGAP2;
          if(wt<T_FTCROSS){
            var clt=wt/T_FTCROSS;
            var cti=Math.floor(clt*20);prevIW=0.8;
            while(tCrossIdx<=cti&&tCrossIdx<=20){drawInk(inkCtx,tCrossPath,tCrossIdx,tCrossW);tCrossIdx++;}
            crossDone=true;
            anim=requestAnimationFrame(animate);return;
          }
          wt-=T_FTCROSS;
          if(wt<T_FGAP3){anim=requestAnimationFrame(animate);return;}
          wt-=T_FGAP3;
          if(!stopDone){drawDot(inkCtx,fullStopPos[0],fullStopPos[1],1.5);addSh(fullStopPos[0],fullStopPos[1],3);stopDone=true;}
          anim=requestAnimationFrame(animate);return;
        }

        // HOLD -- keep the completed signature visible, sheen fading
        if(el<T_WRITE+T_HOLD){
          anim=requestAnimationFrame(animate);return;
        }

        // Done -- stop animating (Swift will fade this out)
      }

      anim=requestAnimationFrame(animate);
    })();
    </script>
    </body>
    </html>
    """
}
