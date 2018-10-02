import {Controller} from 'stimulus';

export default class extends Controller {
  static targets = ["results", "submit", "kindForeignLanguage", "kindLocal", "purposeImport", "purposeExport"];

  beforeSendResults () {
    this.submitTarget.classList.add('is-loading');
  }

  completeResults () {
    this.submitTarget.classList.remove('is-loading');
  }

  errorResults (event) {
    let [data, status, xhr]  = event.detail;
    alert("There was an error. Please report this:\n" + data);
  }

  displayResults (event) {
    let [data, status, xhr]  = event.detail;
    this.resultsTarget.innerHTML = xhr.response;
    if (this.kindForeignLanguageTarget.checked) { this.kindIsForeignLanguage(); }
    if (this.kindLocalTarget.checked)   { this.kindIsLocal(); }
    // The following may not exist, depending on the ajax return
    try {
      if (this.purposeImportTarget.checked) { this.purposeIsImport(); }
      if (this.purposeExportTarget.checked) { this.purposeIsExport(); }
    } catch(err) {}
  }

  kindIsLocal (event) {
    this.hideElements(document.getElementsByClassName('foreign-language-only'));
    this.showElements(document.getElementsByClassName('local-only'));
  }

  kindIsForeignLanguage (event) {
    this.hideElements(document.getElementsByClassName('local-only'));
    this.showElements(document.getElementsByClassName('foreign-language-only'));
  }

  purposeIsImport (event) {
    this.hideElements(document.getElementsByClassName('export-only'));
    this.showElements(document.getElementsByClassName('import-only'));
  }

  purposeIsExport (event) {
    this.hideElements(document.getElementsByClassName('import-only'));
    this.showElements(document.getElementsByClassName('export-only'));
  }

  //Internal Routines

  hideElements (elements) {
    for (let element of elements) {
      element.style.display = 'none'
    }
  }

  showElements (elements) {
    for (let element of elements) {
      element.style.display = ''
    }
  }
}