import { LegalPage } from "../../components/legal/LegalPage";

export function PrivacyPolicyPage() {
  return (
    <LegalPage eyebrow="Legal" title="Privacy Policy" updatedAt="September 21, 2026">
      <p>
        ChatCart provides conversational commerce tools that help businesses answer customer questions,
        recommend products, capture orders, and coordinate fulfilment through supported messaging channels.
        This policy explains how ChatCart handles personal information when customers communicate with a
        participating business through Facebook Messenger, Instagram, WhatsApp, or the ChatCart dashboard.
      </p>

      <section>
        <h2>Information we collect</h2>
        <p>Depending on how you use ChatCart, we may process:</p>
        <ul>
          <li>Messaging identifiers supplied by the connected platform, such as a Page-scoped or WhatsApp identifier.</li>
          <li>Messages and attachments that you choose to send to a participating business.</li>
          <li>Order information, including product choices, quantity, name, phone number, and delivery address.</li>
          <li>Conversation and order status, delivery results, and customer-support history.</li>
          <li>Business-user account information, such as name, email address, role, and authentication records.</li>
          <li>Limited technical logs needed for security, diagnostics, duplicate prevention, and reliable delivery.</li>
        </ul>
      </section>

      <section>
        <h2>How we use information</h2>
        <p>We use this information to:</p>
        <ul>
          <li>Respond to product, price, stock, delivery, and order questions.</li>
          <li>Recommend products using the participating business&apos;s approved catalog and policies.</li>
          <li>Create, confirm, update, fulfil, and support customer orders.</li>
          <li>Allow authorized business staff to review conversations and take over from automation.</li>
          <li>Measure service performance and improve the safety and quality of customer conversations.</li>
          <li>Prevent abuse, investigate errors, and protect customers, businesses, and the service.</li>
        </ul>
      </section>

      <section>
        <h2>Automated assistance</h2>
        <p>
          ChatCart may use automated systems and third-party AI services to understand a message and prepare a
          response. Product prices, availability, order totals, and confirmations are taken from the business&apos;s
          configured data. A customer may ask for a human representative at any time.
        </p>
      </section>

      <section>
        <h2>When information is shared</h2>
        <p>We share information only as needed to operate the service, including with:</p>
        <ul>
          <li>The business that owns the Page, WhatsApp account, catalog, and customer relationship.</li>
          <li>Meta and the messaging platform used to send and receive the conversation.</li>
          <li>Hosting, database, security, and AI service providers acting on our behalf.</li>
          <li>Delivery or commerce providers selected by the business to fulfil a confirmed order.</li>
          <li>Authorities when disclosure is legally required or necessary to protect rights and safety.</li>
        </ul>
        <p>ChatCart does not sell customer personal information.</p>
      </section>

      <section>
        <h2>Retention and security</h2>
        <p>
          Information is retained only for as long as reasonably necessary to provide the service, maintain order
          and business records, resolve disputes, meet legal obligations, and protect the platform. We use access
          controls, encryption where appropriate, secret management, and audit-friendly records to reduce risk.
          No online service can guarantee absolute security.
        </p>
      </section>

      <section>
        <h2>Your choices and rights</h2>
        <p>
          You may ask to access, correct, or delete personal information associated with a ChatCart conversation.
          You may also stop messaging the business or request a human representative. Instructions for deletion are
          available on our <a href="/data-deletion">Data Deletion page</a>.
        </p>
      </section>

      <section>
        <h2>Children</h2>
        <p>
          ChatCart is intended for commercial customer-service conversations and is not directed to children. We do
          not knowingly collect children&apos;s information for targeted advertising or profiling.
        </p>
      </section>

      <section>
        <h2>Changes to this policy</h2>
        <p>
          We may update this policy as the service or legal requirements change. The updated date at the top of this
          page identifies the latest version.
        </p>
      </section>

      <section>
        <h2>Contact</h2>
        <address>
          ChatCart<br />
          160/1, Middle Badda, Dhaka 1212, Bangladesh<br />
          Phone: <a href="tel:+8801725126467">+880 1725-126467</a>
        </address>
      </section>
    </LegalPage>
  );
}
