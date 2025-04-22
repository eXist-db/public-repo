/* global cy */
/// <reference types="cypress" />

context('expath package registry', () => {
  beforeEach(() => {
    cy.visit('')
  })

  describe('landing page', () => {
    it('should contain major parts', () => {
      cy.get('.navbar')
        .should('exist')
      cy.get('.nav-link')
        .should('have.length', '3')
      cy.get('h1')
        .contains('Package Registry')
      cy.get('#package-list > h2')
        .contains('Available Packages')
      cy.get('.packages')
        .should('exist')
      cy.get('#user-docu > h2')
        .contains('Info')
    })
  })
})