import { async, ComponentFixture, TestBed } from '@angular/core/testing';

import { SubsystemsComponent } from './subsystems.component';

describe('SubsystemsComponent', () => {
  let component: SubsystemsComponent;
  let fixture: ComponentFixture<SubsystemsComponent>;

  beforeEach(async(() => {
    TestBed.configureTestingModule({
      declarations: [ SubsystemsComponent ]
    })
    .compileComponents();
  }));

  beforeEach(() => {
    fixture = TestBed.createComponent(SubsystemsComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
