import {Controller} from 'stimulus';

export default class extends Controller {
  static targets = ["results", "submit", "kindForeignLanguage", "kindLocal", "modeCreateCSV", "modeCheck", "purposeImport", "purposeExport"];

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
    this.updateUI();
  }

  updateUI (event) {
    if (this.kindLocalTarget.checked) {
      this.showAndHide('local-only', 'foreign-language-only');
    } else {
      this.showAndHide('foreign-language-only', 'local-only');
      if (this.modeCreateCSVTarget.checked) {
        this.showAndHide('create-csv-only', 'check-only');
        if (this.purposeExportTarget.checked) {
          this.showAndHide('export-only', 'import-only');
        } else {
          this.showAndHide('import-only', 'export-only');
        }
        this.submitTarget.innerText = 'Download CSV';
      } else {
        this.showAndHide('check-only', 'create-csv-only');
        this.submitTarget.innerText = 'Check Addresses';
      }
    }
  }

  showAndHide(showClass, hideClass) {
    this.showElements(document.getElementsByClassName(showClass));
    this.hideElements(document.getElementsByClassName(hideClass));
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