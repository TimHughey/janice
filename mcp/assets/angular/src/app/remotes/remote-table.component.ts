import { Component, OnInit } from '@angular/core';
import { Input, Output } from '@angular/core';

import { RemoteService } from './remote.service';
import { Remote } from './remote';

@Component({
  selector: 'app-remote-table',
  templateUrl: './remote-table.component.html',
  styleUrls: ['./remote-table.component.css']
})
export class RemoteTableComponent implements OnInit {

  remotes: Remote[];
  save: string;
  @Output() pending = new Array<Remote>();

  constructor(private remoteService: RemoteService) { }

  ngOnInit() {
    this.remotes = this.remoteService.getRemotes();
    // this.remoteService.getRemotes().then(remotes => this.remotes = remotes);
  }

  blur({ event: event, local: local }) {
    console.log('blur:', event, this.save, local);
  }

  onEditCancel(event) {
    const changed: Remote = event.data;

    const index = this.remotes.findIndex((item: Remote) => item.id === changed.id);

    event.data.name = this.save;
    // this.remotes[index] = this.save[index];

    console.log('cancel:', event, index);
  }

  onEditComplete(event) {
    this.pending.push(event.data);
    console.log('complete:', event);
  }

  onEditInit(event) {
    this.save = event.data.name;
    console.log('init: ', event, this.save);

  }
}
