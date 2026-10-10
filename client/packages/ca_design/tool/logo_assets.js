// Erzeugt Logo- und App-Symbol-Bilder aus /mnt/project-files/logo (Variante c4-access).
const {chromium}=require('playwright');const fs=require('fs');const path=require('path');
const L='/mnt/project-files/logo/', OUT=process.argv[2];
const strip=s=>s.replace(/<metadata>[\s\S]*?<\/metadata>/,'').replace(/ xmlns:c2pa="[^"]*"/,'');
const logo=strip(fs.readFileSync(L+'c4-access-hell.svg','utf8')).replace('<rect width="558.6" height="222.75" fill="#FFFFFF"/>','');
const variants={hell:logo, dunkel:logo.replace('fill="#0D0E13" transform="translate(24,92.75)"','fill="#F4F4F6" transform="translate(24,92.75)"')};
const icon=strip(fs.readFileSync(L+'icon-c4-access.svg','utf8'));
const inner=icon.replace(/^<svg[^>]*>/,'').replace(/<\/svg>\s*$/,'').replace('<rect width="1024" height="1024" fill="#FFFFFF"/>','');
// Adaptive Android-Symbole: Inhalt in die sichere Mitte (66 %) skalieren.
const scaled=(body)=>`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024"><g transform="translate(512 512) scale(.72) translate(-512 -512)">${body}</g></svg>`;
const mono=`<defs><mask id="m">${inner.replace('fill="#FF5A1F"','fill="#FFF"').replace('fill="#0D0E13"','fill="#000"')}</mask></defs><rect width="1024" height="1024" fill="#000" mask="url(#m)"/>`;
(async()=>{const b=await chromium.launch();const p=await b.newPage();
 const shot=async(svg,w,h,file,transparent)=>{await p.setViewportSize({width:w,height:h});
  await p.setContent(`<style>html,body{margin:0;background:transparent}svg{display:block;width:${w}px;height:${h}px}</style>${svg}`);
  fs.mkdirSync(path.dirname(file),{recursive:true});await p.screenshot({path:file,omitBackground:transparent});};
 for(const [n,svg] of Object.entries(variants)) for(const [d,f] of [['',1],['2.0x/',2],['3.0x/',3]])
   await shot(svg.replace(/width="559" height="223"/,''),Math.round(80*f),Math.round(32*f),`${OUT}/assets/logo/${d}${n}.png`,true);
 await shot(icon.replace(/width="1024" height="1024"/,''),1024,1024,`${OUT}/assets/app-icon/ios-1024.png`,false);
 await shot(scaled(inner),1024,1024,`${OUT}/assets/app-icon/android-vordergrund.png`,true);
 await shot(scaled(mono),1024,1024,`${OUT}/assets/app-icon/android-einfarbig.png`,true);
 // Ab iOS 18: dunkle und getönte Variante (ohne Hintergrund, das System legt ihn darunter).
 const at=(body,k)=>`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">${body}</svg>`;
 await shot(at(inner),1024,1024,`${OUT}/assets/app-icon/ios-dunkel-1024.png`,true);
 const grey=inner.replace('fill="#FF5A1F"','fill="#FFFFFF"').replace('fill="#0D0E13"','fill="#000000"');
 await shot(at(grey),1024,1024,`${OUT}/assets/app-icon/ios-getoent-1024.png`,true);
 // Ebenen für Icon Composer (iOS 26+): Hintergrund, Schild, Buchstaben.
 const g=inner.match(/<g transform="[^"]*">/)[0], rect=inner.match(/<rect x[^>]*\/>/)[0], letters=inner.match(/<path[^>]*\/>/)[0];
 const layer=b=>`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">${b}</svg>`;
 fs.mkdirSync(`${OUT}/assets/app-icon/icon-composer`,{recursive:true});
 fs.writeFileSync(`${OUT}/assets/app-icon/icon-composer/1-hintergrund.svg`,layer('<rect width="1024" height="1024" fill="#FFFFFF"/>'));
 fs.writeFileSync(`${OUT}/assets/app-icon/icon-composer/2-schild.svg`,layer(g+rect+'</g>'));
 fs.writeFileSync(`${OUT}/assets/app-icon/icon-composer/3-buchstaben.svg`,layer(g+letters+'</g>'));
 // Google Play: 512 × 512, Play rundet selbst ab.
 await shot(icon.replace(/width="1024" height="1024"/,''),512,512,`${OUT}/assets/store/play-icon-512.png`,false);
 // Android-Benachrichtigung: weiße Fläche auf transparent, 24 dp (96 px bei xxxhdpi).
 const white=`<defs><mask id="n">${inner.replace('fill="#FF5A1F"','fill="#FFF"').replace('fill="#0D0E13"','fill="#000"')}</mask></defs><rect width="1024" height="1024" fill="#FFF" mask="url(#n)"/>`;
 await shot(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024"><g transform="translate(512 512) scale(1.2) translate(-512 -512)">${white}</g></svg>`,96,96,`${OUT}/assets/app-icon/android-benachrichtigung-96.png`,true);
 await b.close();})();
