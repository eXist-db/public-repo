/* global cy */
/// <reference types="cypress" />

describe('error responses', () => {

    it('returns 404 with the styled error page for an unknown route', () => {
        cy.request({
            url: 'this-does-not-exist',
            failOnStatusCode: false
        }).then((res) => {
            expect(res.status).to.eq(404)
            expect(res.body).to.match(/Page Not Found/i)
        })
    })

    it('renders site chrome on the 404 page (navigation, footer)', () => {
        cy.visit('this-does-not-exist', { failOnStatusCode: false })
        cy.get('h1').contains('Page Not Found')
        cy.get('nav').should('exist')
        cy.get('#copyright').should('exist')
    })

    it('returns structured <error> XML for a non-existent .xar download', () => {
        cy.request({
            url: 'public/nonexistent-99.99.99.xar',
            failOnStatusCode: false
        }).then((res) => {
            expect(res.status).to.eq(404)
            expect(res.headers['content-type']).to.match(/xml/)
            expect(res.body).to.match(/<error>/)
            expect(res.body).to.match(/<status>404<\/status>/)
            expect(res.body).to.contain('nonexistent-99.99.99.xar')
        })
    })

    it('returns structured <error> XML for a non-existent icon', () => {
        cy.request({
            url: 'public/nonexistent-99.99.99.png',
            failOnStatusCode: false
        }).then((res) => {
            expect(res.status).to.eq(404)
            expect(res.headers['content-type']).to.match(/xml/)
            expect(res.body).to.match(/<error>/)
            expect(res.body).to.match(/<status>404<\/status>/)
        })
    })
})
