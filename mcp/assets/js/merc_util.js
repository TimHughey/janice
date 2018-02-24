// function isNumber(value) {
//   return typeof value === 'number' && Number.isFinite(value);
// }

export function humanizeState(data, type, row) {
  if (data) {
    return 'active';
  }

  return 'off';
}

export function prettySeconds(data, type, row) {
  if (data > 0) {
    return prettyMs((data * 1000), {
      compact: true,
    });
  }

  return 'now';
}

export function prettyLastCommand(data, type, row) {
  if (data > 0) {
    return prettyMs((data * 1000), {
      compact: true,
    });
  }

  return '-';
}

export function prettyUs(data, type, row) {
  if (data > 0) {
    return prettyMs((data / 1000), {
      compact: true,
    });
  }

  return '-';
}

export function displayStatus(text) {
  const navBarAlert = jQuery('#navbarAlert');
  navBarAlert.text(text);
  navBarAlert.fadeToggle();
  navBarAlert.fadeOut(3000);
}

/* eslint-disable no-console */
export function dataTableErrorHandler(settings, techNote, message) {
  displayStatus(message);
  console.log(settings, techNote, message);
}

export function autoRefresh() {
  let ari = sessionStorage.getItem('autoRefreshInterval');
  if (ari !== 'undefined') {
    clearInterval(ari);
  }

  ari = setInterval(
    () => {
      if (document.visibilityState === 'visible') {
        const tabs = ['switches', 'sensors', 'remotes'];
        tabs.forEach((elem) => {
          const tabActive = jQuery(`#${elem}Tab`).hasClass('active');
          const table = jQuery(`#${elem}Table`).DataTable();
          const button = table.button(0);

          if (tabActive && (button.active())) {
            button.processing(true);
            table.ajax.reload(() => {
              button.processing(false);
            }, false);
          }
        });
      }
    },
    3000,
  );

  sessionStorage.setItem('autoRefreshInterval', ari);
}

// export default {
//   humanizeState,
//   prettySeconds,
//   prettyLastCommand,
//   prettyUs,
//   displayStatus,
//   dataTableErrorHandler,
//   autoRefresh,
// };
