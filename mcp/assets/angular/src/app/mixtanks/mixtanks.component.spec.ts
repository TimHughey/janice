import { async, ComponentFixture, TestBed } from '@angular/core/testing';

import { MixtanksComponent } from './mixtanks.component';

describe('MixtanksComponent', () => {
  let component: MixtanksComponent;
  let fixture: ComponentFixture<MixtanksComponent>;

  beforeEach(async(() => {
    TestBed.configureTestingModule({
      declarations: [ MixtanksComponent ]
    })
    .compileComponents();
  }));

  beforeEach(() => {
    fixture = TestBed.createComponent(MixtanksComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
