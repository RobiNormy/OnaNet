import { initializeApp } from 'https://www.gstatic.com/firebasejs/11.10.0/firebase-app.js';
import {
  confirmPasswordReset,
  getAuth,
  verifyPasswordResetCode,
} from 'https://www.gstatic.com/firebasejs/11.10.0/firebase-auth.js';

const firebaseConfig = {
  apiKey: 'AIzaSyAkM_ow1lFbgcpJTMI1z_56TapXgruXO6Q',
  authDomain: 'onanet-956af.firebaseapp.com',
  projectId: 'onanet-956af',
};

const auth = getAuth(initializeApp(firebaseConfig));
const params = new URLSearchParams(window.location.search);
const mode = params.get('mode');
const code = params.get('oobCode');

const states = {
  loading: document.querySelector('#loading-state'),
  form: document.querySelector('#form-state'),
  success: document.querySelector('#success-state'),
  invalid: document.querySelector('#invalid-state'),
};

function showState(name) {
  Object.entries(states).forEach(([key, element]) => {
    element.hidden = key !== name;
  });
}

function invalidLink(message) {
  if (message) document.querySelector('#invalid-message').textContent = message;
  showState('invalid');
}

function passwordIsStrong(password) {
  return password.length >= 8 &&
    /[a-z]/.test(password) &&
    /[A-Z]/.test(password) &&
    /\d/.test(password) &&
    /[^A-Za-z0-9]/.test(password);
}

document.querySelectorAll('.password-toggle').forEach((button) => {
  button.addEventListener('click', () => {
    const input = document.querySelector(`#${button.dataset.target}`);
    const showing = input.type === 'text';
    input.type = showing ? 'password' : 'text';
    button.textContent = showing ? 'Show' : 'Hide';
    button.setAttribute('aria-label', `${showing ? 'Show' : 'Hide'} password`);
  });
});

async function prepareReset() {
  if (mode !== 'resetPassword' || !code) {
    invalidLink('This link is incomplete. Return to OnaNet and request a new password-reset email.');
    return;
  }

  try {
    const email = await verifyPasswordResetCode(auth, code);
    document.querySelector('#reset-email').textContent = email;
    showState('form');
  } catch (_) {
    invalidLink();
  }
}

document.querySelector('#reset-form').addEventListener('submit', async (event) => {
  event.preventDefault();
  const password = document.querySelector('#new-password').value;
  const confirmation = document.querySelector('#confirm-password').value;
  const error = document.querySelector('#form-error');
  const button = document.querySelector('#reset-button');

  error.hidden = true;
  if (!passwordIsStrong(password)) {
    error.textContent = 'Use 8+ characters with uppercase, lowercase, a number and a symbol.';
    error.hidden = false;
    return;
  }
  if (password !== confirmation) {
    error.textContent = 'The passwords do not match.';
    error.hidden = false;
    return;
  }

  button.disabled = true;
  button.textContent = 'Resetting password…';
  try {
    await confirmPasswordReset(auth, code, password);
    showState('success');
  } catch (_) {
    invalidLink('This link has expired or was already used. Return to OnaNet and request a new one.');
  }
});

prepareReset();
