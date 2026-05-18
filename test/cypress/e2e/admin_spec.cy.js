/* global cy */
/// <reference types="cypress" />

describe('admin page', () => {
    beforeEach(() => {
        cy.visit('admin')
    })

    it('should contain a navigation bar with 5 entries', () => {
        cy.navBar
    })

    it('should show the login', () => {
        cy.get('h1').contains('Administrator Login')
        cy.get('form').should('exist')
        cy.get('input[name="user"]').should('exist')
        cy.get('input[name="password"]').should('exist')
        cy.get('button[type="submit"]').should('exist')
    })
    
    it('unauthorized user should not see admin section', () => {
        cy.login('blah', 'blah')
        cy.get('h1').should('not.eq','Admin')
    })

    it('authorized user should be able to upload package', () => {
        cy.fixture('test-app.xar', null).as('test-app')
        cy.login('repo', 'repo')
        cy.url().should('include', '/admin')
        cy.get('h1').contains('Admin')
        cy.get('aside > h2').contains('Upload Packages')
        cy.get('#files')
          .selectFile('@test-app')
        cy.get('#upload')
          .click()
        // After fix for #133, stored filename is derived from expath-pkg.xml as {abbrev}-{version}.xar
        cy.get('#uploaded > tr > td')
          .contains('test-app-1.0.1.xar')

        // Confirm the GUI upload produced a downloadable versioned resource at the expected URL
        cy.request('public/test-app-1.0.1.xar').its('status').should('eq', 200)

        cy.reload()
        cy.get('.package-list >h3')
          .contains('test-app')
        cy.get('[href="?logout=true"]')
          .click()
        cy.url().should('not.include', '/admin')
    })

    it('uploading same package twice should not overwrite first version (#133)', () => {
        cy.fixture('test-app.xar', null).as('test-app')
        cy.login('repo', 'repo')
        cy.url().should('include', '/admin')

        // Upload the same package twice - the versioned filename prevents collisions
        cy.get('#files').selectFile('@test-app')
        cy.get('#upload').click()
        cy.get('#uploaded > tr > td')
          .contains('test-app-1.0.1.xar')

        // Second upload of same XAR should succeed (same version overwrites same version, not a different one)
        cy.get('#files').selectFile('@test-app')
        cy.get('#upload').click()
        cy.get('#uploaded > tr > td')
          .contains('test-app-1.0.1.xar')

        cy.get('[href="?logout=true"]').click()
    })
})