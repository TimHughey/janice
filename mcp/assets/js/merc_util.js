// function isNumber(value) {
//   return typeof value === 'number' && Number.isFinite(value);
// }

function humanizeState(data, type, row) {
  if (data) {
    return 'active';
  }

  return 'off';
}

function prettySeconds(data, type, row) {
  if (data > 0) {
    return prettyMs((data * 1000), {
      compact: true,
    });
  }

  return 'now';
}

function prettyLastCommand(data, type, row) {
  if (data > 0) {
    return prettyMs((data * 1000), {
      compact: true,
    });
  }

  return '-';
}

function prettyUs(data, type, row) {
  if (data > 0) {
    return prettyMs((data / 1000), {
      compact: true,
    });
  }

  return '-';
}

function displayStatus(text) {
  const navBarAlert = jQuery('#navbarAlert');
  navBarAlert.text(text);
  navBarAlert.fadeToggle();
  navBarAlert.fadeOut(3000);
}

/* eslint-disable no-console */
function dataTableErrorHandler(settings, techNote, message) {
  displayStatus(techNote);
  console.log(settings, techNote, message);
}

function autoRefresh() {
  let ari = sessionStorage.getItem('autoRefreshInterval');
  if (ari !== 'undefined') {
    clearInterval(ari);
  }

  ari = setInterval(
    () => {
      if (document.visibilityState === 'visible') {
        const tabs = ['switches', 'sensors'];
        tabs.forEach((elem) => {
          const table = jQuery(`#${elem}Table`).DataTable();
          const button = table.button(0).button();

          if (jQuery(`#${elem}Tab`).hasClass('active') && (table.button(0).active())) {
            button.processing(true);
            table.ajax.reload(() => {
              table.button(0).processing(false);
            }, false);
          }
        });
      }
    },
    3000,
  );

  sessionStorage.setItem('autoRefreshInterval', ari);
}

export default {
  humanizeState,
  prettySeconds,
  prettyLastCommand,
  prettyUs,
  displayStatus,
  dataTableErrorHandler,
  autoRefresh,
};
