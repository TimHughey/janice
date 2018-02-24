import * as mercUtil
  from './merc_util';

import * as mercSensorsTable
  from './sensors_table';

import * as mercSwitchesTable
  from './switches_table';

import * as mercRemotesTable
  from './remotes_table';

function pageReady(jQuery) {
  /* eslint-disable no-param-reassign */
  jQuery.fn.dataTable.ext.errMode = mercUtil.dataTableErrorHandler;
  /* eslint-enable no-param-reassign */

  mercSensorsTable.create();
  mercSwitchesTable.create();
  mercRemotesTable.create();
  mercUtil.autoRefresh();

  jQuery('#mixtankProfile,dropdown-item').on('click', (event) => {
    const parent = event.target.parentNode;
    const mixtankName = parent.attributes.mixtankName.value;
    const newProfile = event.target.text;
    // console.log('via div ->', mixtankName, newProfile);
    // console.log(parent);

    jQuery.ajax({
      url: `mcp/api/mixtank/${mixtankName}`,
      type: 'PATCH',
      data: {
        newprofile: newProfile,
      },
      beforeSend(xhr) {
        // send the CSRF token included as a meta on the HTML page
        const token = jQuery("meta[name='csrf-token']").attr('content');
        xhr.setRequestHeader('X-CSRF-Token', token);
      },
      error(xhr, status, error) {
        console.log('error xhr:', xhr);
        mercUtil.displayStatus(`Error activating profile ${newProfile}`);
      },
    }).done((data) => {
      mercUtil.displayStatus(`Activated profile ${data.active_profile}`);
      // console.log(data);
    });

    jQuery('#dropdownMenuButton').text(newProfile);
  });

  jQuery('a[href="#switchesTab"]').on('shown.bs.tab', (event) => {
    $('#switchesTable').DataTable().ajax.reload(null, false);
  });

  jQuery('a[href="#sensorsTab"]').on('shown.bs.tab', (event) => {
    $('#sensorsTable').DataTable().ajax.reload(null, false);
  });

  document.addEventListener(
    'visibilitychange', mercUtil.autoRefresh,
    false,
  );
}

function pageFullyLoaded() {
  setTimeout(() => {
    const masthead = jQuery('#mastheadText');
    masthead.removeClass('text-muted').addClass('text-ready');
  }, 10);
}

jQuery(document).ready(pageReady);

jQuery(window).on('load', pageFullyLoaded);
