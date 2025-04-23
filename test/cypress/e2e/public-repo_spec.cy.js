/* global cy */
/// <reference types="cypress" />

context('expath package registry', () => {
  const navBar = () => {
    cy.get('.navbar').should('exist')
    cy.get('.nav-link').should('have.length', 5)
  };

  describe('landing page', () => {
    beforeEach(() => {
      cy.visit('')
    })

    it('should contain a navigation bar', navBar)

    it('should have the default main title', () => {
      cy.get('h1.hero').contains('EXPath Package Registry')
    })

    it('should have an Installation section', () => {
      cy.get('#installation > h2').contains('Installation')
    })
  })

  describe('list page', () => {
    beforeEach(() => {
      cy.visit('list')
    })

    it('should contain a navigation bar', navBar)

    it('should have the page title', () => {
      cy.get('h1').contains('Available Packages')
    })

    it('should have an list of packages', () => {
      cy.get('.package-list').should('exist')
    })
  })

  describe('search page', () => {
    beforeEach(() => {
      cy.visit('search')
    })

    it('should contain a navigation bar', navBar)

    it('should have the page title', () => {
      cy.get('h1').contains('Package Search')
    })
  })

  describe('admin page', () => {
    beforeEach(() => {
      cy.visit('admin')
    })

    it('should contain a navigation bar', navBar)

    it('should show the login', () => {
      cy.get('h1').contains('Administrator Login')
    })

    // TODO
    // login
    // upload
  })

  describe('stats page', () => {
    beforeEach(() => {
      cy.visit('stats')
    })

    it('should contain a navigation bar', navBar)

    it('should have the page title', () => {
      cy.get('h1').contains('Statistics')
    })
  })

})