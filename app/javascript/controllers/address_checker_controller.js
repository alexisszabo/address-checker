import {Controller} from 'stimulus';

export default class extends Controller {
  static targets = ["results", "submit"];

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
  }
}