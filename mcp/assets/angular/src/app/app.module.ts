import { BrowserModule } from '@angular/platform-browser';
import { BrowserAnimationsModule } from '@angular/platform-browser/animations';
import { NgModule } from '@angular/core';
import { HttpClientModule } from '@angular/common/http';
import { FormsModule } from '@angular/forms';
import { Angular2FontawesomeModule } from 'angular2-fontawesome/angular2-fontawesome';

import { ButtonModule } from 'primeng/primeng';
import { CheckboxModule } from 'primeng/checkbox';
import { ConfirmDialogModule } from 'primeng/confirmdialog';
import { InputTextModule } from 'primeng/inputtext';
import { MenuModule } from 'primeng/menu';
import { MenubarModule } from 'primeng/menubar';
import { MessagesModule } from 'primeng/messages';
import { MessageService } from 'primeng/components/common/messageservice';
import { ProgressSpinnerModule } from 'primeng/progressspinner';
import { TableModule } from 'primeng/table';
import { ToggleButtonModule } from 'primeng/togglebutton';

import { AppComponent } from './app.component';
import { RemoteTableComponent } from './remotes/remote-table.component';
import { RemoteService } from './remotes/remote.service';
import { AppRoutingModule } from './app-routing.module';
import { LandingComponent } from './landing/landing.component';
import { SubsystemsComponent } from './subsystems/subsystems.component';
import { RemotesComponent } from './remotes/remotes.component';


@NgModule({
  declarations: [
    AppComponent,
    RemoteTableComponent,
    LandingComponent,
    SubsystemsComponent,
    RemotesComponent
  ],
  imports: [
    BrowserModule,
    BrowserAnimationsModule,
    HttpClientModule,
    Angular2FontawesomeModule,
    InputTextModule,
    ButtonModule,
    CheckboxModule,
    ConfirmDialogModule,
    FormsModule,
    MenuModule,
    MenubarModule,
    MessagesModule,
    ProgressSpinnerModule,
    TableModule,
    ToggleButtonModule,
    AppRoutingModule
  ],
  providers: [MessageService, RemoteService],
  bootstrap: [AppComponent]
})
export class AppModule { }
