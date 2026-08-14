const query = new URLSearchParams(window.location.search);
const fragment = new URLSearchParams(window.location.hash.replace(/^#/, ''));
const error = query.get('error') || fragment.get('error');
const errorCode = query.get('error_code') || fragment.get('error_code');
const cameFromVerification =
  query.get('source') === 'email-verification' || fragment.has('access_token');

if (error || errorCode || !cameFromVerification) {
  document.querySelector('#verified-state').hidden = true;
  document.querySelector('#verification-error-state').hidden = false;
}

window.history.replaceState({}, document.title, '/verify-email');
