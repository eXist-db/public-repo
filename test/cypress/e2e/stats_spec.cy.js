/* global cy */
/// <reference types="cypress" />

describe('stats page', () => {
    beforeEach(() => {
        cy.visit('stats')
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
    
    it('unauthorized user should not see statistics', () => {
        cy.login('blah', 'blah')
        cy.get('h1').should('not.eq', 'Statistics')
    })

    it('authorized user should be able to see statistics', () => {
        cy.login('repo', 'repo')
        cy.url().should('include', '/stats')
        cy.get('h1').contains('Statistics')
    })
})