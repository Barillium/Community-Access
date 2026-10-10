import {DirectoryError} from './directory.mjs';

// A bounded catalogue avoids pretending that a keyword classifier proves legality.
export const questionCatalogue = [
 'Was interessiert dich an unserem Programm?',
 'Welche Musik möchtest du hören?',
 'Welche Veranstaltungsformate interessieren dich?',
 'Hast du die Veranstaltungsregeln gelesen?',
 'What interests you about our programme?',
 'Which music would you like to hear?',
 'Which event formats interest you?',
 'Have you read the event rules?',
];
export function checkedForm(value) {
 if(!Array.isArray(value)||value.length>12)throw new DirectoryError(422,'INVALID_FORM');
 const keys=new Set();
 return value.map(f=>{
  if(!f||typeof f.key!=='string'||!/^[a-z][a-z0-9_]{0,39}$/.test(f.key)||keys.has(f.key)||typeof f.required!=='boolean')throw new DirectoryError(422,'INVALID_FORM');
  keys.add(f.key);
  if(typeof f.label!=='string'||!questionCatalogue.includes(f.label.trim()))throw new DirectoryError(422,'FORM_REVIEW_REQUIRED');
  return {key:f.key,label:f.label.trim(),required:f.required};
 });
}
