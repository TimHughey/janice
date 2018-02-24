import {
  prettySeconds,
  prettyUs,
  displayStatus,
  autoRefresh,
  prettyLastCommand,
  humanizeState,
}
  from './merc_util';

function switchesColumns() {
  return [{
    data: 'id',
    class: 'col-center',
  },
  {
    data: 'name',
  }, {
    data: 'device',
  }, {
    data: 'description',
  },
  {
    data: 'dev_latency',
    class: 'col-center',
    render: prettyUs,
  }, {
    data: 'rt_latency',
    class: 'col-center',
    render: prettyUs,
  }, {
    data: 'last_cmd_secs',
    class: 'col-center',
    render: prettyLastCommand,
  }, {
    data: 'last_seen_secs',
    class: 'col-center',
    render: prettySeconds,
  }, {
    data: 'state',
    class: 'col-state-off',
    render: humanizeState,
  },
  ];
}

function create() {
  const switchTable = jQuery('#switchesTable').DataTable({
    dom: 'Bfrtip',
    ajax: 'mcp/api/switch',
    scrollY: '50vh',
    // deferRender: true,
    scroller: true,
    select: {
      style: 'single',
      items: 'row',
    },
    order: [
      [1, 'asc'],
    ],
    columns: switchesColumns(),
    columnDefs: [
      {
        targets: [0],
        visible: false,
        searchable: false,
      },
    ],
    buttons: [{
      text: 'Refresh',
      action(e, dt, node, config) {
        if (switchTable.button(0).active()) {
          switchTable.button(0).active(false);
        } else {
          switchTable.button(0).active(true);
          autoRefresh();
        }
      },
    },
    {
      text: 'Rename',
      extend: 'selected',
      attr: {
        id: 'switchRenameButton',
      },
      action(e, dt, node, config) {
        const {
          name,
          id,
        } = switchTable.rows({
          selected: true,
        }).data()[0];

        const newName = jQuery('#generalInputBox').val();

        switchTable.button(1).processing(true);
        jQuery.ajax({
          url: `mcp/api/switch/${id}`,
          type: 'PATCH',
          data: {
            name: newName,
          },
          dataType: 'json',
          beforeSend(xhr) {
            // send the CSRF token included as a meta on the HTML page
            const token = jQuery("meta[name='csrf-token']").attr('content');
            xhr.setRequestHeader('X-CSRF-Token', token);
          },
          error(xhr, status, error) {
            console.log('error xhr:', xhr);
            displayStatus(`Error changing name of ${name}`);
          },
          success(data, status, jqXHR) {
            console.log(data, status, jqXHR);
            displayStatus(`Switch name changed to ${data.name}`);
            // const response = jqXHR.responseJSON();
            // displayStatus(`Switch name changed to ${response.name}`);
          },
          complete(xhr, status) {
            switchTable.ajax.reload(null, false);
            switchTable.button(1).processing(false);
            jQuery('#generalPurposeForm').fadeToggle();
            switchTable.button(0).active(true);
          },
        });
      },
    },
    {
      text: 'Delete',
      extend: 'selected',
      attr: {
        id: 'switchDeleteButton',
      },
      action(e, dt, node, config) {
        const {
          device,
        } = switchTable.rows({
          selected: true,
        }).data()[0];

        switchTable.button(2).processing(true);
        jQuery.ajax({
          url: `mcp/api/switch/${encodeURIComponent(device)}`,
          type: 'DELETE',
          beforeSend(xhr) {
            // send the CSRF token included as a meta on the HTML page
            const token = jQuery("meta[name='csrf-token']").attr('content');
            xhr.setRequestHeader('X-CSRF-Token', token);
          },
          error(xhr, status, error) {
            console.log('error xhr:', xhr);
            displayStatus(`Error deleting ${device}`);
          },
          success(xhr, status) {
            displayStatus(`Deleted switch ${device}`);
          },
          complete(xhr, status) {
            switchTable.ajax.reload(null, false);
            switchTable.button(2).processing(false);
            jQuery('#generalPurposeForm').fadeToggle();
            switchTable.button(0).active(true);
          },
        });
      },
    },
    {
      text: 'Toggle',
      extend: 'selected',
      attr: {
        id: 'switchToggleButton',
      },
      action(e, dt, node, config) {
        const {
          name,
          id,
        } = switchTable.rows({
          selected: true,
        }).data()[0];

        switchTable.button(3).processing(true);

        jQuery.ajax({
          url: `mcp/api/switch/${id}`,
          type: 'PATCH',
          data: {
            toggle: true,
          },
          beforeSend(xhr) {
            // send the CSRF token included as a meta on the HTML page
            const token = jQuery("meta[name='csrf-token']").attr('content');
            xhr.setRequestHeader('X-CSRF-Token', token);
          },
          error(jqXHR, status, error) {
            console.log('error xhr:', jqXHR);
            displayStatus(`Error toggling ${name}`);
          },
          success(data, status, jqXHR) {
            displayStatus(`Toggled switch ${name}`);
          },
          complete(xhr, status) {
            switchTable.ajax.reload(null, false);
            switchTable.button(3).processing(false);
            jQuery('#generalPurposeForm').fadeToggle();
            switchTable.button(0).active(true);
          },
        });
      },
    }],
  });

  switchTable.button(0).active(true);

  switchTable.on('select', (e, dt, type, indexes) => {
    switchTable.button(0).active(false);

    const inputBox = jQuery('#generalPurposeForm');

    jQuery('#generalInputBox').attr(
      'placeholder',
      'Enter new switch name then click Rename',
    );
    inputBox.fadeIn('fast');
  });

  switchTable.on('deselect', (e, dt, type, indexes) => {
    const inputBox = jQuery('#generalPurposeForm');
    switchTable.button(0).active(true);

    inputBox.fadeOut('fast');
  });
}

export default {
  create,
};
