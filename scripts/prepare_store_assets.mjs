// Rasterize the existing favicon SVG into native/store assets. No new brand design or upload.
import {createRequire} from 'node:module';
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
if(!process.env.CA_PLAYWRIGHT_MODULE)throw Error('Point CA_PLAYWRIGHT_MODULE at an existing Playwright installation. Nothing is installed.');
const require=createRequire(import.meta.url);
const {chromium}=require(process.env.CA_PLAYWRIGHT_MODULE);
const source=await readFile(path.join(root,'client/web/favicon.svg'),'utf8');
if(/(?:href|https?:|script|image)/i.test(source.replace('http://www.w3.org/2000/svg','')))throw Error('Only the reviewed standalone vector source is supported.');
const browser=await chromium.launch({headless:true});
try{
 const page=await browser.newPage({viewport:{width:1024,height:1024}});
 await page.route('**/*',route=>route.abort());
 await page.setContent('<!doctype html><html><body style="margin:0"><canvas></canvas></body></html>');
 async function png(size){
  const encoded=await page.evaluate(async({source,size})=>{
   const image=new Image();image.src='data:image/svg+xml;base64,'+btoa(source);await image.decode();
   const canvas=document.querySelector('canvas');canvas.width=canvas.height=size;
   const context=canvas.getContext('2d');context.fillStyle='#151515';context.fillRect(0,0,size,size);context.drawImage(image,0,0,size,size);
   return canvas.toDataURL('image/png').split(',')[1];
  },{source,size});
  return Buffer.from(encoded,'base64');
 }
 const assets=path.join(root,'docs/store-launch/assets');await mkdir(assets,{recursive:true});
 await writeFile(path.join(assets,'app-icon-1024.png'),await png(1024));
 await writeFile(path.join(assets,'google-play-icon-512.png'),await png(512));
 const ios=path.join(root,'client/ios/Runner/Assets.xcassets/AppIcon.appiconset');
 const manifest=JSON.parse(await readFile(path.join(ios,'Contents.json'),'utf8'));
 for(const entry of manifest.images){if(entry.filename)await writeFile(path.join(ios,entry.filename),await png(Math.round(parseFloat(entry.size)*parseFloat(entry.scale))));}
 for(const [density,size] of Object.entries({mdpi:48,hdpi:72,xhdpi:96,xxhdpi:144,xxxhdpi:192})){
  const directory=path.join(root,'client/android/app/src/main/res',`mipmap-${density}`);await mkdir(directory,{recursive:true});await writeFile(path.join(directory,'ic_launcher.png'),await png(size));
 }
 const adaptive=path.join(root,'client/android/app/src/main/res/mipmap-anydpi-v26');await mkdir(adaptive,{recursive:true});
 await writeFile(path.join(adaptive,'ic_launcher.xml'),'<?xml version="1.0" encoding="utf-8"?><adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android"><background android:drawable="@color/launcher_background"/><foreground android:drawable="@drawable/launcher_foreground"/></adaptive-icon>\n');
 const drawable=path.join(root,'client/android/app/src/main/res/drawable');
 await writeFile(path.join(drawable,'launcher_foreground.xml'),'<?xml version="1.0" encoding="utf-8"?><vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="108dp" android:height="108dp" android:viewportWidth="108" android:viewportHeight="108"><path android:fillColor="#00000000" android:strokeColor="#FFFFFFFF" android:strokeWidth="3" android:pathData="M29,54 a18,18 0,1 0,36 0 a18,18 0,1 0,-36 0 M43,54 a18,18 0,1 0,36 0 a18,18 0,1 0,-36 0"/></vector>\n');
 const values=path.join(root,'client/android/app/src/main/res/values');await writeFile(path.join(values,'launcher_colors.xml'),'<?xml version="1.0" encoding="utf-8"?><resources><color name="launcher_background">#151515</color></resources>\n');
 for(const [language,subtitle] of Object.entries({de:'Events. Communities. Persönlicher Zugang.',en:'Events. Communities. Personal access.'})){
  const encoded=await page.evaluate(async({source,subtitle})=>{
   const canvas=document.querySelector('canvas');canvas.width=1024;canvas.height=500;const context=canvas.getContext('2d');context.fillStyle='#151515';context.fillRect(0,0,1024,500);
   const image=new Image();image.src='data:image/svg+xml;base64,'+btoa(source);await image.decode();context.drawImage(image,52,126,248,248);
   context.fillStyle='#FFFFFF';context.font='bold 64px Arial';context.fillText('Community',340,205);context.fillText('Access',340,279);context.font='24px Arial';context.fillText(subtitle,342,337);
   return canvas.toDataURL('image/png').split(',')[1];
  },{source,subtitle});
  await writeFile(path.join(assets,`google-play-feature-${language}-1024x500.png`),Buffer.from(encoded,'base64'));
 }
 await writeFile(path.join(assets,'README.md'),'# Store-Bildmaterial\n\nAus dem vorhandenen `client/web/favicon.svg` gerendert; keine neue Markenform erfunden. Native App-Icons sowie Apple-1024- und Google-512-Icon sind PNG ohne transparente Ecken. Google-Featuregrafiken: 1024 × 500, DE/EN. Layout vor Verwendung prüfen. Diese Grafiken sind keine Gerätescreenshots. Tatsächliche native Store-Screenshots und Geräteabnahme fehlen noch. Keine Dateien hochgeladen.\n');
 console.log('Existing brand rasterized into native and store assets; nothing uploaded.');
}finally{await browser.close();}
