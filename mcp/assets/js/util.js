export default class JanUtil {
  constructor() {
    this.constructed = true;
  }

  static autoRefresh(data) {
    let ari = sessionStorage.getItem('autoRefreshInterval');
    if (ari !== 'undefined') {
      clearInterval(ari);
    }

    ari = setInterval(
      () => {
        if (document.visibilityState === 'visible') {
          const tabs = ['switches', 'sensors', 'remotes', 'dutycycles',
            'mixtanks'];
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

  static boolToYesNo(data) {
    return (data) ? 'yes' : 'no';
  }

  /* eslint-disable no-console */
  static dataTableErrorHandler(settings, techNote, message) {
    JanUtil.displayStatus(message);
    console.log(settings, techNote, message);
  }

  static displayStatus(text) {
    const navBarAlert = jQuery('#navbarAlert');
    navBarAlert.text(text);
    navBarAlert.fadeToggle();
    navBarAlert.fadeOut(3000);
  }

  static humanizeState(data, type, row) {
    return (data) ? 'active' : 'off';
  }

  static prettyLastCommand(data, type, row) {
    if (data > 0) {
      return prettyMs((data * 1000), {
        compact: true,
      });
    }

    return '-';
  }

  static prettySeconds(data, type, row) {
    if (data === null) {
      return '-';
    }

    if (data === 0) {
      return 'now';
    }

    let opts = {};
    if (data > (60 * 60)) {
      opts = {
        compact: true,
      };
    }

    return prettyMs((data * 1000), opts);
  }

  static prettyUs(data, type, row) {
    if (data > 0) {
      return prettyMs((data / 1000), {
        compact: true,
      });
    }

    return '-';
  }
}
