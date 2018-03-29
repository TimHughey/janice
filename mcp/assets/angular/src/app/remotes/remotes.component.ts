import { Component, OnInit } from '@angular/core';
import { Message } from 'primeng/components/common/api';
import { MessageService } from 'primeng/components/common/messageservice';

@Component({
  selector: 'app-remotes',
  templateUrl: './remotes.component.html',
  styleUrls: ['./remotes.component.css'],
  providers: [MessageService]
})
export class RemotesComponent implements OnInit {

  constructor(private messageService: MessageService) { }

  ngOnInit() {
  }

}
