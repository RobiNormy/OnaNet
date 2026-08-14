import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const states = {
  loading: document.querySelector('#loading-state'),
  form: document.querySelector('#form-state'),
  success: document.querySelector('#success-state'),
  invalid: document.querySelector('#invalid-state'),
};

let supabase;

function showState(name) {
  Object.entries(states).forEach(([key, element]) => {
    element.hidden = key !== name;
  });
}

function invalidLink(message) {
  if (message) document.querySelector('#invalid-message').textContent = message;
  showState('invalid');
}

function showSuccess() {
  showState('success');
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

async function prepareRecovery() {
  try {
    const response = await fetch('https://api.onanet.app/auth/public-config', {
      headers: { Accept: 'application/json' },
    });
    if (!response.ok) throw new Error('Configuration unavailable');
    const config = await response.json();
    supabase = createClient(
      config.supabase_url,
      config.supabase_publishable_key,
      { auth: { detectSessionInUrl: true, persistSession: false } },
    );

    const { data, error } = await supabase.auth.getSession();
    if (error || !data.session) {
      invalidLink();
      return;
    }

    const email = data.session.user?.email;
    document.querySelector('#reset-email').textContent = email || 'your OnaNet account';
    showState('form');
  } catch (_) {
    invalidLink('Password reset is temporarily unavailable. Please try again later or contact OnaNet support.');
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
  const { error: updateError } = await supabase.auth.updateUser({ password });
  if (updateError) {
    button.disabled = false;
    button.textContent = 'Reset password';
    error.textContent = updateError.message || 'Could not update your password. Request a new reset link.';
    error.hidden = false;
    return;
  }

  await supabase.auth.signOut();
  window.history.replaceState({}, document.title, '/reset-password');
  showSuccess();
});

prepareRecovery();
